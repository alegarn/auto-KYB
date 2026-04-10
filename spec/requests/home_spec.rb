require 'rails_helper'

RSpec.describe "Homes", type: :request, inertia: true do
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
    end

    context "when authenticated" do
      let(:user) { create(:user, :subscribed, plan: :pro, onboarding_completed: true) }
      let(:session_record) { user.sessions.create! }
      let(:crm_transfer_query) { instance_double(CrmTransferSignalsQuery, call: nil) }
      let(:dashboard_query) { instance_double(DashboardQuery, onboarding_summary: nil) }

      before do
        allow(CrmTransferSignalsQuery).to receive(:new).and_return(crm_transfer_query)
        allow(DashboardQuery).to receive(:new).with(user).and_return(dashboard_query)

        cookies["session_token"] = session_record.id
      end

      it "shares auth and session state for public CTA switching" do
        get "/"

        expect(inertia.props.dig(:auth, :user, :email)).to eq(user.email)
        expect(inertia.props[:session_id]).to eq(session_record.id)
      end
    end
  end
end
