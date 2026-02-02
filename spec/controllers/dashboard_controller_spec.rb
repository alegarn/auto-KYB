require "rails_helper"

RSpec.describe DashboardController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password123456") }

  describe "GET #index" do
    context "when authenticated" do
      let(:session) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session.id
      end

      it "renders inertia with Dashboard component" do
        get :index

        expect(inertia.component).to eq("Dashboard/Dashboard")
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
  end
end
