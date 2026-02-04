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
      expect(response).to have_http_status(:found)

      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'bar' }, validate: true } }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(client_portal_confirmation_path)
      expect(response.cookies["client_form_session"]).to be_nil

      @client_form.reload
      expect(@client_form.validated_at).not_to be_nil
      expect(@client_form.status).to eq(ClientForm.statuses['validated'])
    end

    it "rejects updates when client_form is locked (validated)" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect(response).to have_http_status(:found)

      # Validate first
      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'bar' }, validate: true } }
      expect(response).to have_http_status(:see_other)

      # Login again to get cookie (session cleared on validate)
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect(response).to have_http_status(:found)

      # Attempt to save after validation should redirect to login (session cleared/locked)
      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'baz' } } }
      expect(response).to have_http_status(:see_other)
      expect(response.headers["Location"]).to include("/client_portal/login")
    end

    it "rejects updates when client_form is expired" do
      @client_form.update!(expires_at: 1.day.ago)

      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect(response).to have_http_status(:found)

      patch client_portal_form_response_path, params: { form_response: { data: { foo: 'bar' } } }
      expect(response).to have_http_status(:see_other)
      expect(response.headers["Location"]).to include("/client_portal/login")
    end
  end
end
require "rails_helper"

RSpec.describe "ClientPortal::FormResponses", type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:form) { create(:form, user: user) }

  before do
    @client_form = ClientForm.create!(client: client, form: form)
    password = "secret-pass-#{SecureRandom.hex(4)}"
    @client_form.password = password
    @client_form.save!
    @password = password
  end

  describe "GET /client_portal/form_response (show)" do
    it "renders the form payload when authenticated" do
      allow(ClientPortal::SessionService).to receive(:current_client_form).with(anything).and_return(@client_form)

      get client_portal_form_response_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(form.name)
    end
  end

  describe "POST /client_portal/form_response (update)" do
    it "creates a FormResponse and sets status to filled on first save" do
      allow(ClientPortal::SessionService).to receive(:current_client_form).with(anything).and_return(@client_form)

      expect {
        patch client_portal_form_response_path, params: { form_response: { data: { foo: "bar" } } }, as: :json
      }.to change { FormResponse.count }.by(1)

      @client_form.reload
      expect(@client_form.status).to eq(ClientForm.statuses['filled'])
      fr = FormResponse.last
      expect(fr.data).to include('foo' => 'bar')
      expect(fr.version).to eq(1)
    end

    it "validates and locks the client_form when validate flag is true" do

      allow(ClientPortal::SessionService).to receive(:current_client_form).with(anything).and_return(@client_form)

      patch client_portal_form_response_path, params: { form_response: { data: { ok: true }, validate: true } }, as: :json

      @client_form.reload
      expect(@client_form.status).to eq(ClientForm.statuses['validated'])
      expect(@client_form.validated_at).not_to be_nil
      # session cookie should be cleared; subsequent access should redirect to login
      get client_portal_form_response_path
      expect(response).to have_http_status(:see_other)
      expect(response.headers["Location"]).to include("/client_portal/login")
    end
  end
end
