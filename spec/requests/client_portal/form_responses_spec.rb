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
