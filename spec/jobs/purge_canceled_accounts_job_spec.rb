# frozen_string_literal: true

require "rails_helper"

RSpec.describe PurgeCanceledAccountsJob, type: :job do
  describe "#perform" do
    context "when there are no expired canceled accounts" do
      it "does not destroy any users" do
        create(:user, :canceled)   # canceled today — not yet expired
        expect { described_class.perform_now }.not_to change(User, :count)
      end
    end

    context "when there are accounts canceled more than 1 year ago" do
      let!(:expired_user) { create(:user, :canceled_over_a_year_ago, stripe_customer_id: nil) }
      let!(:recent_user)  { create(:user, :canceled) }

      it "destroys users canceled over 1 year ago" do
        expect { described_class.perform_now }.to change(User, :count).by(-1)
        expect(User.exists?(expired_user.id)).to be false
      end

      it "does not destroy users canceled less than 1 year ago" do
        described_class.perform_now
        expect(User.exists?(recent_user.id)).to be true
      end
    end

    context "when an expired user has an active Stripe subscription" do
      let!(:expired_user) do
        create(:user, :canceled_over_a_year_ago, stripe_subscription_id: "sub_exp_1")
      end

      it "attempts to cancel the Stripe subscription before destroying" do
        allow(Stripe::Subscription).to receive(:cancel).with("sub_exp_1")
        described_class.perform_now
        expect(Stripe::Subscription).to have_received(:cancel).with("sub_exp_1")
      end

      it "still destroys the user if Stripe already canceled the subscription" do
        allow(Stripe::Subscription).to receive(:cancel).and_raise(
          Stripe::InvalidRequestError.new("No such subscription", "sub_exp_1")
        )
        expect { described_class.perform_now }.to change(User, :count).by(-1)
      end
    end

    context "when one user fails to destroy" do
      let!(:expired_user1) { create(:user, :canceled_over_a_year_ago) }
      let!(:expired_user2) { create(:user, :canceled_over_a_year_ago) }

      it "continues purging remaining users" do
        call_count = 0
        allow_any_instance_of(User).to receive(:destroy!).and_wrap_original do |method, *args|
          call_count += 1
          raise ActiveRecord::RecordNotDestroyed.new("fail", nil) if call_count == 1
          method.call(*args)
        end

        expect { described_class.perform_now }.to change(User, :count).by(-1)
      end
    end
  end
end
