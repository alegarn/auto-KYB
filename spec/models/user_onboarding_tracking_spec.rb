require "rails_helper"

RSpec.describe User, type: :model do
  describe "dashboard onboarding tracking" do
    let(:user) { create(:user, :subscribed, plan: :basic) }

    it "returns the default dashboard onboarding state" do
      expect(user.dashboard_onboarding_state).to eq(
        "dismissed_at" => nil,
        "detailed_view_seen_at" => nil,
        "demo_seeded_at" => nil,
        "restarted_at" => nil,
        "data_exported_at" => nil,
        "guides_seen" => {},
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

    it "marks a guide as seen and ignores invalid guide keys" do
      travel_to(Time.zone.parse("2026-04-07 11:00:00 UTC")) do
        user.mark_dashboard_onboarding_guide_seen!(:form_builder)
      end

      user.reload
      expect(user.dashboard_onboarding_guide_seen?(:form_builder)).to be(true)
      expect(user.dashboard_onboarding_guides_seen).to eq("form_builder" => "2026-04-07T11:00:00Z")

      # Invalid key is silently ignored
      expect(user.mark_dashboard_onboarding_guide_seen!(:nonexistent)).to be_nil
    end

    it "clears guides_seen on reset with reset_progress" do
      user.mark_dashboard_onboarding_guide_seen!(:form_builder)
      user.reset_dashboard_onboarding!(reset_progress: true)

      user.reload
      expect(user.dashboard_onboarding_guides_seen).to eq({})
    end
  end
end