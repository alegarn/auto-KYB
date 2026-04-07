require "rails_helper"

RSpec.describe OnboardingController, type: :controller do
  let(:user) { create(:user, :subscribed, plan: :basic) }
  let(:session_record) { user.sessions.create! }

  before do
    cookies.signed[:session_token] = session_record.id
  end

  describe "PATCH #dismiss" do
    it "updates only the dashboard onboarding dismissal state" do
      expect {
        patch :dismiss
      }.to change { user.reload.dashboard_onboarding_dismissed_at }.from(nil)

      expect(response).to redirect_to(dashboard_path)
      expect(response).to have_http_status(:see_other)
      expect(user.reload.onboarding_completed).to be(false)
      expect(user.dashboard_onboarding_detailed_view_seen_at).to be_nil
    end
  end

  describe "PATCH #details_seen" do
    it "updates only the dashboard onboarding details state" do
      expect {
        patch :details_seen
      }.to change { user.reload.dashboard_onboarding_detailed_view_seen_at }.from(nil)

      expect(response).to redirect_to(dashboard_path)
      expect(response).to have_http_status(:see_other)
      expect(user.reload.onboarding_completed).to be(false)
      expect(user.dashboard_onboarding_dismissed_at).to be_nil
    end
  end

  context "when not authenticated" do
    before do
      cookies.delete(:session_token)
    end

    it "redirects dismiss to sign in" do
      patch :dismiss

      expect(response).to redirect_to(sign_in_path)
    end

    it "redirects details_seen to sign in" do
      patch :details_seen

      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when authenticated without dashboard access" do
    let(:user) { create(:user, :canceled, plan: :basic) }

    it "redirects dismiss to the subscription-required page" do
      patch :dismiss

      expect(response).to redirect_to(subscription_required_path)
      expect(response).to have_http_status(:see_other)
    end

    it "redirects details_seen to the subscription-required page" do
      patch :details_seen

      expect(response).to redirect_to(subscription_required_path)
      expect(response).to have_http_status(:see_other)
    end
  end
end