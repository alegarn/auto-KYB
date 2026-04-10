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

  describe "PATCH #guide_seen" do
    it "marks a valid guide as seen" do
      expect {
        patch :guide_seen, params: { guide_key: "form_builder" }
      }.to change { user.reload.dashboard_onboarding_guides_seen["form_builder"] }.from(nil)

      expect(response).to redirect_to(dashboard_path)
      expect(response).to have_http_status(:see_other)
      expect(user.reload.onboarding_completed).to be(false)
    end

    it "rejects an invalid guide key" do
      expect {
        patch :guide_seen, params: { guide_key: "unknown" }
      }.not_to change { user.reload.dashboard_onboarding_guides_seen }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH #reset" do
    before do
      user.dismiss_dashboard_onboarding!
      user.mark_dashboard_onboarding_details_seen!
      user.mark_dashboard_onboarding_guide_seen!(:form_builder)
    end

    it "clears dashboard ui state and guide progress when reset_progress is true" do
      expect {
        patch :reset, params: { reset_progress: true }
      }.to change { user.reload.dashboard_onboarding_guides_seen }.from(include("form_builder" => kind_of(String))).to({})

      user.reload

      expect(response).to redirect_to(dashboard_path)
      expect(response).to have_http_status(:see_other)
      expect(user.dashboard_onboarding_dismissed_at).to be_nil
      expect(user.dashboard_onboarding_detailed_view_seen_at).to be_nil
      expect(user.dashboard_onboarding_restarted_at).to be_present
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

    it "redirects guide_seen to sign in" do
      patch :guide_seen, params: { guide_key: "form_builder" }

      expect(response).to redirect_to(sign_in_path)
    end

    it "redirects reset to sign in" do
      patch :reset, params: { reset_progress: true }

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

    it "redirects guide_seen to the subscription-required page" do
      patch :guide_seen, params: { guide_key: "form_builder" }

      expect(response).to redirect_to(subscription_required_path)
      expect(response).to have_http_status(:see_other)
    end

    it "redirects reset to the subscription-required page" do
      patch :reset, params: { reset_progress: true }

      expect(response).to redirect_to(subscription_required_path)
      expect(response).to have_http_status(:see_other)
    end
  end
end