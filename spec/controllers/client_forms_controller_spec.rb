require "rails_helper"

RSpec.describe ClientFormsController, type: :controller do
  let(:user) { create(:user, :subscribed) }
  let(:session_record) { user.sessions.create! }

  before do
    cookies.signed[:session_token] = session_record.id
  end

  describe "GET #export_responses" do
    it "returns CSV for owner when authenticated" do
      client = create(:client, user: user)
      form = create(:form, user: user)
      client_form = create(:client_form, client: client, form: form)

      csv_payload = "header1,header2\r\nval1,val2\r\n"
      allow(FormResponseExportService).to receive(:call).with(client_form).and_return(csv_payload)

      get :export_responses, params: { id: client_form.id, format: :csv }

      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("form-responses-#{client_form.id}")
      expect(response.body).to eq(csv_payload)
    end

    it "redirects to sign_in when not authenticated" do
      cookies.signed[:session_token] = nil

      get :export_responses, params: { id: 1, format: :csv }

      expect(response).to redirect_to(sign_in_path)
    end

    it "raises 404 for non-existent client_form" do
      expect {
        get :export_responses, params: { id: 9_999_999, format: :csv }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "redirects with alert when accessing another user's client_form" do
      other_user = create(:user)
      other_client = create(:client, user: other_user)
      form = create(:form, user: other_user)
      other_client_form = create(:client_form, client: other_client, form: form)

      # ensure current_user is set via cookie (already set in before block)
      get :export_responses, params: { id: other_client_form.id, format: :csv }

      expect(response).to redirect_to(clients_path)
      expect(flash[:alert]).to eq("You don't have permission to access this form")
    end

    it "returns JSON payload when format=json" do
      client = create(:client, user: user)
      form = create(:form, user: user)
      client_form = create(:client_form, client: client, form: form)

      json_payload = { foo: "bar" }
      allow(FormResponseExportService).to receive(:as_json_payload).with(client_form).and_return(json_payload)

      get :export_responses, params: { id: client_form.id, format: :json }

      expect(response.content_type).to include("application/json")
      expect(response.body).to include("\"foo\":\"bar\"")
    end
  end
end
