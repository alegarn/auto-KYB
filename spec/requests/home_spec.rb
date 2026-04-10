require 'rails_helper'

RSpec.describe "Homes", type: :request, inertia: true do
  def stub_authenticated_home_queries(user)
    allow(CrmTransferSignalsQuery).to receive(:new)
      .and_return(instance_double(CrmTransferSignalsQuery, call: nil))
    allow(DashboardQuery).to receive(:new)
      .with(user)
      .and_return(instance_double(DashboardQuery, onboarding_summary: nil))
  end

  describe "GET /index" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    it "renders the Home/Index Inertia component" do
      get "/"

      expect(inertia.component).to eq("Home/Index")
    end

    it "shares no authenticated landing state for guests" do
      get "/"

      expect(inertia.props[:auth]).to be_nil
      expect(inertia.props[:session_id]).to be_nil
      expect(inertia.props[:public_auth_cta]).to be_nil
    end

    context "when authenticated with a completed subscription" do
      let(:user) { create(:user, :subscribed, plan: :pro, onboarding_completed: true) }
      let(:session_record) { user.sessions.create! }

      before do
        stub_authenticated_home_queries(user)
        cookies["session_token"] = session_record.id
      end

      it "shares a dashboard CTA for the public header" do
        get "/"

        expect(inertia.props.dig(:auth, :user, :email)).to eq(user.email)
        expect(inertia.props[:session_id]).to eq(session_record.id)
        expect(inertia.props[:public_auth_cta]).to eq({
          label: "Dashboard",
          href: dashboard_path
        })
      end
    end

    context "when authenticated with auth setup still pending" do
      let(:user) { create(:user, :subscribed, plan: :pro, onboarding_completed: false) }
      let(:session_record) { user.sessions.create! }

      before do
        stub_authenticated_home_queries(user)
        cookies["session_token"] = session_record.id
      end

      it "shares a finish setup CTA for the public header" do
        get "/"

        expect(inertia.props[:public_auth_cta]).to eq({
          label: "Finish Setup",
          href: auth_setup_settings_path
        })
      end
    end

    context "when authenticated with a retained canceled subscription" do
      let(:user) { create(:user, :canceled, plan: :pro, onboarding_completed: false) }
      let(:session_record) { user.sessions.create! }

      before do
        stub_authenticated_home_queries(user)
        cookies["session_token"] = session_record.id
      end

      it "shares a resume subscription CTA for the public header" do
        get "/"

        expect(inertia.props[:public_auth_cta]).to eq({
          label: "Resume Subscription",
          href: sign_up_path
        })
      end
    end
  end
end
