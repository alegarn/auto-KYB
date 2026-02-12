require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "POST /sign_up" do
    context "with nested registration and password" do
      let(:params) do
        { registration: { email: "user@example.com", password: "securepass123", password_confirmation: "securepass123" } }
      end

      it "creates a user and sets a session cookie" do
        expect {
          post "/sign_up", params: params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:redirect)
        expect(response.cookies['session_token']).to be_present
      end
    end

    context "with missing password" do
      let(:params) do
        { registration: { email: "bad@example.com", password: "" } }
      end

      it "does not create a user and returns 422" do
        expect {
          post "/sign_up", params: params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /sign_up" do
    let!(:user) { User.create!(email: "to-delete@example.com", password: "password123456") }
    let!(:session_record) { user.sessions.create! }

    before do
      cookies.signed[:session_token] = session_record.id
    end

    it "deletes the user and associated records when confirmation is valid" do
      form = user.forms.create!(name: "KYB Form")
      form.form_fields.create!(label: "Company name", field_type: "text", required: true)
      client = user.clients.create!(name: "Alice", company_name: "Acme")
      client_form = ClientForm.create!(client: client, form: form)
      FormResponse.create!(client_form: client_form, data: { company_name: "Acme" })
      form_field_id = form.form_fields.first.id
      form_id = form.id
      client_id = client.id
      client_form_id = client_form.id
      form_response_id = client_form.form_responses.first.id
      session_id = session_record.id

      expect do
        delete "/sign_up", params: { confirmation: "DELETE" }
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to(root_path)
      expect(Form.exists?(form_id)).to be(false)
      expect(FormField.exists?(form_field_id)).to be(false)
      expect(Client.exists?(client_id)).to be(false)
      expect(ClientForm.exists?(client_form_id)).to be(false)
      expect(FormResponse.exists?(form_response_id)).to be(false)
      expect(Session.exists?(session_id)).to be(false)
    end

    it "does not delete the account when confirmation is invalid" do
      expect do
        delete "/sign_up", params: { confirmation: "WRONG" }
      end.not_to change(User, :count)

      expect(response).to redirect_to(settings_path)
    end

    it "redirects unauthenticated users to sign in" do
      delete "/sign_up", params: { confirmation: "DELETE" }, headers: { "Cookie" => "" }

      expect(response).to redirect_to(sign_in_path)
    end
  end
end
