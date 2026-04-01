require "rails_helper"

RSpec.describe Crm::Entitlement, type: :service do
  describe "#reason" do
    it "returns unauthenticated when there is no user" do
      entitlement = described_class.new(nil)

      expect(entitlement.reason).to eq(:unauthenticated)
      expect(entitlement).not_to be_allowed
      expect(entitlement).not_to be_plan_eligible
      expect(entitlement).not_to be_subscription_active
      expect(entitlement).not_to be_auto_sync_allowed
    end

    it "returns subscription_inactive for a basic user without an active subscription" do
      user = create(:user, plan: :basic, subscription_status: :incomplete, crm_auto_sync_on_portal_submit: true)
      entitlement = described_class.new(user)

      expect(entitlement.reason).to eq(:subscription_inactive)
      expect(entitlement).not_to be_allowed
      expect(entitlement).not_to be_plan_eligible
      expect(entitlement).not_to be_subscription_active
      expect(entitlement).not_to be_auto_sync_allowed
    end

    it "returns plan_insufficient for an active basic user" do
      user = create(:user, :subscribed, plan: :basic, crm_auto_sync_on_portal_submit: true)
      entitlement = described_class.new(user)

      expect(entitlement.reason).to eq(:plan_insufficient)
      expect(entitlement).not_to be_allowed
      expect(entitlement).not_to be_plan_eligible
      expect(entitlement).to be_subscription_active
      expect(entitlement).not_to be_auto_sync_allowed
    end

    it "returns allowed for an active pro user" do
      user = create(:user, :subscribed, plan: :pro, crm_auto_sync_on_portal_submit: true)
      entitlement = described_class.new(user)

      expect(entitlement.reason).to eq(:allowed)
      expect(entitlement).to be_allowed
      expect(entitlement).to be_plan_eligible
      expect(entitlement).to be_subscription_active
      expect(entitlement).to be_auto_sync_allowed
    end

    it "returns allowed for a trialing pro user" do
      user = create(:user, :trialing, plan: :pro, crm_auto_sync_on_portal_submit: true)
      entitlement = described_class.new(user)

      expect(entitlement.reason).to eq(:allowed)
      expect(entitlement).to be_allowed
      expect(entitlement).to be_plan_eligible
      expect(entitlement).to be_subscription_active
      expect(entitlement).to be_auto_sync_allowed
    end

    it "returns subscription_inactive for a canceled pro user" do
      user = create(:user, :canceled, plan: :pro, crm_auto_sync_on_portal_submit: true)
      entitlement = described_class.new(user)

      expect(entitlement.reason).to eq(:subscription_inactive)
      expect(entitlement).not_to be_allowed
      expect(entitlement).to be_plan_eligible
      expect(entitlement).not_to be_subscription_active
      expect(entitlement).not_to be_auto_sync_allowed
    end
  end

  describe "#as_json" do
    it "serializes the entitlement result with string reason values" do
      user = create(:user, :subscribed, plan: :pro, crm_auto_sync_on_portal_submit: false)

      expect(described_class.new(user).as_json).to eq(
        allowed: true,
        reason: "allowed",
        plan_eligible: true,
        subscription_active: true,
        auto_sync_allowed: false
      )
    end
  end
end