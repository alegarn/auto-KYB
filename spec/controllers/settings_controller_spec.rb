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

        expect(inertia.props[:user]).to eq(user)
      end

      it "passes session_id as prop" do
        get :index

        expect(inertia.props[:session_id]).to eq(session.id)
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
