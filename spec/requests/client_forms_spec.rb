require "rails_helper"

RSpec.describe "ClientForms", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  describe "POST /client_forms" do
    it "creates a client_form and redirects to invitation delivery decision and stores a one-time password in session" do
      user = sign_in_user
      client = FactoryBot.create(:client, user: user)
      form = FactoryBot.create(:form, user: user)

      post client_forms_path, params: { client_form: { client_id: client.id, form_id: form.id } }

      cf = ClientForm.order(:created_at).last
      expect(response).to redirect_to(client_form_invitation_delivery_path(cf))

      expect(session[:client_form_one_time_passwords]).to be_present
      entry = session[:client_form_one_time_passwords][cf.id.to_s]
      expect(entry).to be_present
      expect(entry["password"]).to be_a(String)
      expect(entry["expires_at"]).to be_present
      expect(entry["decision_pending"]).to be true
    end
  end

  describe "GET /client_forms/:id/password_reveal" do
    it "redirects to invitation delivery when decision is still pending" do
      user = sign_in_user
      client = FactoryBot.create(:client, user: user)
      form = FactoryBot.create(:form, user: user)

      post client_forms_path, params: { client_form: { client_id: client.id, form_id: form.id } }
      cf = ClientForm.order(:created_at).last

      get password_reveal_client_form_path(cf)
      expect(response).to redirect_to(client_form_invitation_delivery_path(cf))
    end

    it "reveals the password once after decision is completed and then removes it from session" do
      user = sign_in_user
      client = FactoryBot.create(:client, user: user)
      form = FactoryBot.create(:form, user: user)

      post client_forms_path, params: { client_form: { client_id: client.id, form_id: form.id } }
      cf = ClientForm.order(:created_at).last

      entry = session[:client_form_one_time_passwords][cf.id.to_s]
      one_time = entry["password"]

      # Complete the decision via "Not now"
      post client_form_invitation_delivery_path(cf), params: { send_now: "false" }
      expect(response).to redirect_to(password_reveal_client_form_path(cf))

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(one_time)

      # session entry should be removed after reveal
      expect((session[:client_form_one_time_passwords] || {})[cf.id.to_s]).to be_nil

      # second access should not reveal the password
      get password_reveal_client_form_path(cf)
      expect(response.body).not_to include(one_time)
    end

    it "expires the password reveal after 5 minutes" do
      user = sign_in_user
      client = FactoryBot.create(:client, user: user)
      form = FactoryBot.create(:form, user: user)

      post client_forms_path, params: { client_form: { client_id: client.id, form_id: form.id } }
      cf = ClientForm.order(:created_at).last

      entry = session[:client_form_one_time_passwords][cf.id.to_s]
      one_time = entry["password"]

      # Complete decision first
      post client_form_invitation_delivery_path(cf), params: { send_now: "false" }

      travel 6.minutes

      get password_reveal_client_form_path(cf)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(one_time)
      expect(response.body).to include("Password no longer available or expired.")
    end
  end
end
