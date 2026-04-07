require "rails_helper"

RSpec.describe "ClientPortal::Sessions", type: :request do
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

  describe "POST /client_portal/login/:access_token" do
    it "sets a signed http-only cookie on successful login" do
      https!
      post client_portal_login_path(@client_form.access_token), params: { password: @password }

      expect(response).to have_http_status(:found)
      set_cookie = response.headers["Set-Cookie"] || ""
      expect(set_cookie).to include("client_form_session=")
    end

    it "does not set cookie with invalid password" do
      post client_portal_login_path(@client_form.access_token), params: { password: "wrong" }

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(client_portal_login_path(@client_form.access_token))
      set_cookie = response.headers["Set-Cookie"] || ""
      expect(set_cookie).not_to include("client_form_session=")
    end

    it "returns 429 after too many failed attempts from the same IP + access token" do
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
      headers = { "REMOTE_ADDR" => "203.0.113.10" }

      5.times do
        post client_portal_login_path(@client_form.access_token), params: { password: "wrong" }, headers: headers
        expect(response).to redirect_to(client_portal_login_path(@client_form.access_token))
      end

      post client_portal_login_path(@client_form.access_token), params: { password: "wrong" }, headers: headers
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "GET /client_portal/login/:access_token" do
    it "renders the login page with access token" do
      get client_portal_login_path(@client_form.access_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ClientPortal/Login")
    end
  end

  describe "DELETE /client_portal/logout" do
    it "clears the client_form_session cookie" do
      https!
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect(response).to have_http_status(:found)

      delete client_portal_logout_path
      expect(response).to have_http_status(:found)
      expect(response.cookies["client_form_session"]).to be_nil
    end
  end
end
