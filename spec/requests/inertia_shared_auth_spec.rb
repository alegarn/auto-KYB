# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Inertia Shared Auth State", type: :request do
  let(:inertia_headers) { { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest } }

  describe "inertia_share :auth" do
    context "when the user is not authenticated" do
      it "shares auth: nil" do
        get sign_in_path, headers: inertia_headers
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth")).to be_nil
      end
    end

    context "when the user is authenticated with an active subscription" do
      let(:user) { create(:user, :subscribed) }

      before do
        session_record = user.sessions.create!
        get dashboard_path, headers: inertia_headers.merge(
          "Cookie" => "session_token=#{session_record.id}"
        )
      end

      it "shares auth.user.email" do
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth", "user", "email")).to eq(user.email)
      end

      it "shares auth.subscription.active as true" do
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth", "subscription", "active")).to be true
      end

      it "shares auth.subscription.status as active" do
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth", "subscription", "status")).to eq("active")
      end

      it "shares auth.subscription.canceled_at as nil" do
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth", "subscription", "canceled_at")).to be_nil
      end

      it "shares auth.user.onboarding_completed" do
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth", "user", "onboarding_completed")).to eq(user.onboarding_completed)
      end
    end

    context "when the user has a canceled subscription" do
      let(:canceled_at) { 1.month.ago }
      let(:user) { create(:user, :canceled, subscription_canceled_at: canceled_at) }

      before do
        session_record = user.sessions.create!
        get subscription_required_path, headers: inertia_headers.merge(
          "Cookie" => "session_token=#{session_record.id}"
        )
      end

      it "shares auth.subscription.active as false" do
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth", "subscription", "active")).to be false
      end

      it "shares auth.subscription.canceled_at as ISO8601 string" do
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth", "subscription", "canceled_at")).to be_a(String)
      end
    end
  end
end
