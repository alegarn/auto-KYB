require "rails_helper"

RSpec.describe DashboardController, type: :controller, inertia: true do
  let(:user) { create(:user, :subscribed, plan: :basic, password: "password123456") }
  let(:onboarding_summary) do
    {
      visible: true,
      variant: "basic",
      progress_percent: 33,
      completion_rule: "basic_core",
      quick_steps: [],
      can_dismiss: true,
      detailed_view_seen: false
    }
  end
  let(:dashboard_query) do
    instance_double(
      DashboardQuery,
      clients_scope: Client.none,
      recent_forms: [],
      stats: {
        total_clients: 0,
        validated_clients: 0,
        active_clients: 0,
        linked_clients: 0
      },
      total_clients_count: 0,
      onboarding_summary: onboarding_summary
    )
  end

  describe "GET #index" do
    context "when authenticated" do
      let(:session) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session.id
        allow(DashboardQuery).to receive(:new).with(user).and_return(dashboard_query)
        allow(controller).to receive(:pagy).and_return([
          instance_double(Pagy, page: 1, vars: { items: 10 }),
          []
        ])
        allow(InertiaRails).to receive(:defer) { |&block| block.call }
      end

      it "renders inertia with Dashboard component" do
        get :index

        expect(inertia.component).to eq("Dashboard/Dashboard")
      end

      it "passes the default user props" do
        get :index

        expect(inertia.props[:user]).to include(
          id: user.id,
          email: user.email,
          plan: user.plan,
          crm_auto_sync_on_portal_submit: user.crm_auto_sync_on_portal_submit
        )
      end

      it "passes onboarding only on the dashboard payload" do
        get :index

        expect(inertia.props[:onboarding]).to eq(onboarding_summary)
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
end
