require "rails_helper"

RSpec.describe "ClientPortal::FormResponses", type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:form) { create(:form, user: user) }

  before do
    @client_form = create(:client_form, client: client, form: form)
    password = "secret-pass-#{SecureRandom.hex(4)}"
    @client_form.password = password
    @client_form.save!
    @password = password
  end

  describe "PATCH /client_portal/form_response" do
    it "validates, locks, clears session and redirects to confirmation" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([302, 303]).to include(response.status)

      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'bar' }, validate: true } }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(client_portal_confirmation_path)
      expect(response.cookies["client_form_session"]).to be_nil

      @client_form.reload
      expect(@client_form.validated_at).not_to be_nil
      expect(@client_form.status).to eq(ClientForm.statuses['validated'])
    end

    it "returns inertia props on partial save" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([302, 303]).to include(response.status)

      patch client_portal_form_response_path,
            params: { form_response: { data: { foo: 'bar' }, partial: true } },
            headers: { 'X-Inertia' => 'true' }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig('props', 'last_response', 'data')).to include('foo' => 'bar')
      expect(body.dig('props', 'flash_message', 'type')).to eq('notice')
    end

    it "rejects updates when client_form is locked (validated)" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([302, 303]).to include(response.status)

      # Validate first
      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'bar' }, validate: true } }
      expect(response).to have_http_status(:see_other)

      # Login again to get cookie (session cleared on validate)
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(client_portal_login_path(@client_form.access_token))

      # Attempt to save after validation should redirect to root (session cleared/locked)
      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'baz' } } }, headers: { 'X-Inertia' => 'true' }
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(root_path)
    end

    it "rejects updates when client_form is expired" do
      @client_form.update!(expires_at: 1.day.ago)

      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(client_portal_login_path(@client_form.access_token))

      # Attempt to save should redirect to root (form expired)
      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'bar' } } }, headers: { 'X-Inertia' => 'true' }
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /client_portal/form_response (show)" do
    it "renders the form payload when authenticated" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([302, 303]).to include(response.status)

      get client_portal_form_response_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(form.name)
    end
  end

  describe "PATCH /client_portal/form_response (update)" do
    it "creates a FormResponse and sets status to filled on first save" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([302, 303]).to include(response.status)

      expect {
        patch client_portal_form_response_path,
              params: { form_response: { data: { foo: "bar" } } },
              headers: { 'X-Inertia' => 'true' }
      }.to change { FormResponse.count }.by(1)

      @client_form.reload
      expect(@client_form.status).to eq(ClientForm.statuses['filled'])
      fr = FormResponse.last
      expect(fr.data).to include('foo' => 'bar')
      expect(fr.version).to eq(1)
    end

    it "validates and locks the client_form when validate flag is true" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([302, 303]).to include(response.status)

      patch client_portal_form_response_path,
            params: { form_response: { data: { ok: true }, validate: true } },
            headers: { 'X-Inertia' => 'true' }

      @client_form.reload
      expect(@client_form.status).to eq(ClientForm.statuses['validated'])
      expect(@client_form.validated_at).not_to be_nil
      # session cookie should be cleared; subsequent access should return 409 (version mismatch due to locked form)
      get client_portal_form_response_path, headers: { 'X-Inertia' => 'true' }
      expect(response).to have_http_status(:conflict)
      expect(response.headers['X-Inertia-Location']).to be_present
    end
  end
end
