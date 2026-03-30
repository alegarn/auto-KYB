require "rails_helper"

RSpec.describe CrmFeaturePolicy do
  describe "#access?" do
    it "delegates access checks to the CRM entitlement" do
      user = create(:user)
      entitlement = instance_double(Crm::Entitlement, allowed?: true, reason: :allowed)

      allow(Crm::Entitlement).to receive(:new).with(user).and_return(entitlement)

      policy = described_class.new(user, :crm_feature)

      expect(policy.access?).to be(true)
      expect(Crm::Entitlement).to have_received(:new).with(user)
    end
  end

  describe "#reason" do
    it "exposes the entitlement denial reason" do
      user = create(:user)
      entitlement = instance_double(Crm::Entitlement, allowed?: false, reason: :subscription_inactive)

      allow(Crm::Entitlement).to receive(:new).with(user).and_return(entitlement)

      policy = described_class.new(user, :crm_feature)

      expect(policy.reason).to eq(:subscription_inactive)
    end
  end
end