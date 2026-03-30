require "rails_helper"

RSpec.describe SettingsController, type: :controller, inertia: true do
  let(:user) { User.create!(email: "test@example.com", password: "password123456") }

  describe "GET #index" do
    context "when authenticated" do
      let(:session) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session.id
      end

      it "renders inertia with Settings component" do
        get :index

        expect(inertia.component).to eq("Settings/Index")
      end

      it "passes user as prop" do
        get :index

        expect(inertia.props[:user]).to include(
          "id" => user.id,
          "email" => user.email,
          "plan" => user.plan,
          "subscription_status" => user.subscription_status,
          "crm_auto_sync_on_portal_submit" => user.crm_auto_sync_on_portal_submit,
          :can_use_crm => false
        )
      end

      it "hides CRM connections for users without CRM access" do
        create(:crm_connection, user: user, status: "active")

        get :index

        expect(inertia.props[:crm_connections]).to eq([])
      end

      it "passes session_id as prop" do
        get :index

        expect(inertia.props[:session_id]).to eq(session.id)
      end
    end

    context "when the user can use CRM" do
      let(:user) { create(:user, :subscribed, plan: :pro, password: "password123456") }
      let(:session) { user.sessions.create! }
      let!(:connection) { create(:crm_connection, user: user, provider: "hubspot", status: "active") }

      before do
        cookies.signed[:session_token] = session.id
      end

      it "passes the CRM-enabled user flag and active connections" do
        get :index

        expect(inertia.props[:user][:can_use_crm]).to be(true)
        expect(inertia.props[:crm_connections]).to contain_exactly(
          hash_including(
            "id" => connection.id,
            "provider" => connection.provider,
            "status" => connection.status
          )
        )
      end
    end

    context "when the user has a pro plan without active CRM entitlement" do
      let(:user) { create(:user, :canceled, plan: :pro, password: "password123456") }
      let(:session) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session.id
        create(:crm_connection, user: user, provider: "hubspot", status: "active")
      end

      it "keeps the CRM flag false and hides CRM connections" do
        get :index

        expect(inertia.props[:user][:can_use_crm]).to be(false)
        expect(inertia.props[:crm_connections]).to eq([])
      end
    end

    context "when not authenticated" do
      it "redirects to sign in path" do
        get :index

        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when session token is invalid" do
      before do
        cookies.signed[:session_token] = "invalid_token"
      end

      it "redirects to sign in path" do
        get :index

        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "PATCH #update_crm_preferences" do
    let(:session) { user.sessions.create! }

    before do
      cookies.signed[:session_token] = session.id
    end

    it "updates the CRM portal auto-sync preference" do
      patch :update_crm_preferences, params: {
        settings: {
          crm_auto_sync_on_portal_submit: false
        }
      }

      expect(response).to redirect_to(settings_path)
      expect(response).to have_http_status(:see_other)
      expect(user.reload.crm_auto_sync_on_portal_submit).to be(false)
    end
  end
end
