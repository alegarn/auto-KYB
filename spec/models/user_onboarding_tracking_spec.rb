require "rails_helper"

RSpec.describe User, type: :model do
  describe "dashboard onboarding tracking" do
    let(:user) { create(:user, :subscribed, plan: :basic) }

    it "returns the default dashboard onboarding state" do
      expect(user.dashboard_onboarding_state).to eq(
        "dismissed_at" => nil,
        "detailed_view_seen_at" => nil,
        "demo_seeded_at" => nil,
        "version" => OnboardingTracking::DASHBOARD_ONBOARDING_STATE_VERSION
      )
    end

    it "writes a normalized dismissal timestamp once" do
      travel_to(Time.zone.parse("2026-04-07 09:00:00 UTC")) do
        user.dismiss_dashboard_onboarding!

        expect(user.reload.dashboard_onboarding_dismissed_at).to eq(Time.current)
        expect(user.dashboard_onboarding_state["dismissed_at"]).to eq(Time.current.iso8601)
      end

      original_timestamp = user.reload.dashboard_onboarding_dismissed_at

      travel_to(Time.zone.parse("2026-04-07 12:00:00 UTC")) do
        expect(user.dismiss_dashboard_onboarding!).to eq(original_timestamp)
        expect(user.reload.dashboard_onboarding_dismissed_at).to eq(original_timestamp)
      end
    end

    it "marks the detailed view as seen without overwriting dismissal" do
      dismissal_time = Time.zone.parse("2026-04-07 09:00:00 UTC")
      details_time = Time.zone.parse("2026-04-07 10:00:00 UTC")

      travel_to(dismissal_time) do
        user.dismiss_dashboard_onboarding!
      end

      travel_to(details_time) do
        user.mark_dashboard_onboarding_details_seen!
      end

      user.reload

      expect(user.dashboard_onboarding_dismissed_at).to eq(dismissal_time)
      expect(user.dashboard_onboarding_detailed_view_seen_at).to eq(details_time)
      expect(user.dashboard_onboarding_detailed_view_seen?).to be(true)
    end

    it "treats stale versions as not dismissed for the current onboarding version" do
      user.update!(
        onboarding_state: {
          dismissed_at: Time.zone.parse("2026-04-07 09:00:00 UTC").iso8601,
          version: 0
        }
      )

      expect(user.dashboard_onboarding_version).to eq(0)
      expect(user.dashboard_onboarding_dismissed?).to be(false)
    end

    it "writes a new dismissal timestamp when a stale version is dismissed again" do
      user.update!(
        onboarding_state: {
          dismissed_at: Time.zone.parse("2026-04-07 09:00:00 UTC").iso8601,
          version: 0
        }
      )

      travel_to(Time.zone.parse("2026-04-08 09:00:00 UTC")) do
        expect(user.dismiss_dashboard_onboarding!).to eq(Time.current)
      end

      user.reload

      expect(user.dashboard_onboarding_version).to eq(OnboardingTracking::DASHBOARD_ONBOARDING_STATE_VERSION)
      expect(user.dashboard_onboarding_dismissed_at).to eq(Time.zone.parse("2026-04-08 09:00:00 UTC"))
      expect(user.dashboard_onboarding_dismissed?).to be(true)
    end
  end
end