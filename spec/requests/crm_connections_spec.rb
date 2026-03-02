require 'rails_helper'

RSpec.describe "CrmConnections", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_user(user)
    # Mock subscription policy so authorize_subscription passes
    allow_any_instance_of(SubscriptionPolicy).to receive(:active?).and_return(true)
  end

  describe "POST /crm_connections" do
    it "redirects to HubSpot authorization url" do
      post "/crm_connections", params: { provider: "hubspot" }
      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("https://app.hubspot.com/oauth/authorize")
      expect(session[:crm_oauth_state]).to be_present
    end

    it "redirects back with alert for unsupported provider" do
      post "/crm_connections", params: { provider: "unsupported" }
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to include("Unsupported CRM provider.")
    end
  end

  describe "GET /crm_connections/:provider/callback" do
    let(:state) { "valid_state" }

    before do
      # Set state in test session helper
      post "/crm_connections", params: { provider: "hubspot" }
    end

    it "creates a connection and redirects to settings on success" do
      valid_state = session[:crm_oauth_state]
      
      tokens = {
        access_token: "acc",
        refresh_token: "ref",
        expires_in: 1800
      }
      allow_any_instance_of(Crm::Hubspot::OAuth).to receive(:exchange_code).with("valid_code").and_return(tokens)

      expect {
        get "/crm_connections/hubspot/callback", params: { code: "valid_code", state: valid_state }
      }.to change(CrmConnection, :count).by(1)

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("HubSpot connected successfully!")
      
      conn = user.crm_connections.last
      expect(conn.access_token).to eq("acc")
      expect(conn.status).to eq("active")
    end

    it "redirects with alert on invalid state" do
      get "/crm_connections/hubspot/callback", params: { code: "valid_code", state: "invalid_state" }
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("Invalid OAuth state. Please try again.")
    end
  end

  describe "DELETE /crm_connections/:id" do
    let!(:connection) { create(:crm_connection, user: user, status: "active", access_token: "acc", refresh_token: "ref") }

    it "disconnects the integration" do
      delete "/crm_connections/#{connection.id}"
      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to include("disconnected")

      connection.reload
      expect(connection.status).to eq("disconnected")
      expect(connection.access_token).to be_nil
      expect(connection.refresh_token).to be_nil
    end
  end
end
