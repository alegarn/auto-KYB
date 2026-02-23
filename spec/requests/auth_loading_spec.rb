require "rails_helper"

RSpec.describe "AuthLoading", type: :request do
  let(:user) { create(:user) }
  let(:session_record) { user.sessions.create! }
  let(:inertia_headers) { { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest } }

  describe "GET /auth/loading" do
    it "redirects unauthenticated users to sign in" do
      get auth_loading_path

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(sign_in_path)
    end

    it "renders the Auth/Loading Inertia page with expected props" do
      cookies.signed[:session_token] = session_record.id

      get auth_loading_path, headers: inertia_headers

      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Inertia"]).to eq("true")

      payload = JSON.parse(response.body)
      expect(payload["component"]).to eq("Auth/Loading")
      expect(payload.dig("props", "redirect_to")).to eq(dashboard_path)
      expect(payload.dig("props", "bootstrap_ready")).to eq(true)
    end
  end
end
