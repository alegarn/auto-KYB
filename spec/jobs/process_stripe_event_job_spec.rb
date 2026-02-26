# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessStripeEventJob, type: :job do
  def event_for(type, data_object)
    { 'type' => type, 'id' => "evt_test_#{SecureRandom.hex(4)}", 'data' => { 'object' => data_object } }
  end

  # ─────────────────────────────────────────────────────────────
  # checkout.session.completed
  # ─────────────────────────────────────────────────────────────
  describe "checkout.session.completed" do
    context "when the session object is nil" do
      it "returns early without creating a user" do
        expect {
          described_class.perform_now(event: event_for('checkout.session.completed', nil))
        }.not_to change(User, :count)
      end
    end

    context "when customer_id is blank" do
      it "returns early without creating a user" do
        session_data = { 'customer' => '', 'subscription' => 'sub_1', 'customer_details' => { 'email' => 'x@y.com' } }
        expect {
          described_class.perform_now(event: event_for('checkout.session.completed', session_data))
        }.not_to change(User, :count)
      end
    end

    context "when no user exists for that customer_id" do
      let(:session_data) do
        {
          'customer'         => 'cus_new_1',
          'subscription'     => 'sub_new_1',
          'customer_details' => { 'email' => 'new@example.com' }
        }
      end

      it "creates a verified active user and enqueues the passwordless mail" do
        expect {
          described_class.perform_now(event: event_for('checkout.session.completed', session_data))
        }.to change(User, :count).by(1)
          .and have_enqueued_mail(UserMailer, :passwordless)

        user = User.last
        expect(user.email).to eq('new@example.com')
        expect(user.stripe_customer_id).to eq('cus_new_1')
        expect(user.stripe_subscription_id).to eq('sub_new_1')
        expect(user.subscription_status).to eq('active')
        expect(user.verified).to be true
      end
    end

    context "when a user already exists for that customer_id" do
      let!(:user) { create(:user, stripe_customer_id: 'cus_upd_1', subscription_status: 'incomplete', stripe_subscription_id: nil) }

      let(:session_data) do
        {
          'customer'         => 'cus_upd_1',
          'subscription'     => 'sub_upd_1',
          'customer_details' => { 'email' => user.email }
        }
      end

      it "updates subscription_status to active" do
        expect {
          described_class.perform_now(event: event_for('checkout.session.completed', session_data))
          user.reload
        }.to change(user, :subscription_status).from('incomplete').to('active')
      end

      it "updates stripe_subscription_id" do
        expect {
          described_class.perform_now(event: event_for('checkout.session.completed', session_data))
          user.reload
        }.to change(user, :stripe_subscription_id).from(nil).to('sub_upd_1')
      end

      it "does not create another user" do
        expect {
          described_class.perform_now(event: event_for('checkout.session.completed', session_data))
        }.not_to change(User, :count)
      end

      context "when already active with same subscription id (idempotent)" do
        before { user.update!(subscription_status: 'active', stripe_subscription_id: 'sub_upd_1') }

        it "does not change subscription_status" do
          expect {
            described_class.perform_now(event: event_for('checkout.session.completed', session_data))
            user.reload
          }.not_to change(user, :subscription_status)
        end

        it "does not change stripe_subscription_id" do
          expect {
            described_class.perform_now(event: event_for('checkout.session.completed', session_data))
            user.reload
          }.not_to change(user, :stripe_subscription_id)
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # customer.subscription.updated
  # ─────────────────────────────────────────────────────────────
  describe "customer.subscription.updated" do
    context "when the subscription object is nil" do
      it "returns early without error" do
        expect {
          described_class.perform_now(event: event_for('customer.subscription.updated', nil))
        }.not_to raise_error
      end
    end

    context "when no user matches the customer_id" do
      it "returns early without error" do
        sub = { 'id' => 'sub_x', 'customer' => 'cus_missing', 'status' => 'active' }
        expect {
          described_class.perform_now(event: event_for('customer.subscription.updated', sub))
        }.not_to raise_error
      end
    end

    context "when a matching user exists" do
      let!(:user) do
        create(:user, stripe_customer_id: 'cus_sub_1', subscription_status: 'incomplete',
               stripe_subscription_id: nil, subscription_ends_at: nil)
      end

      it "updates subscription_status" do
        sub = { 'id' => 'sub_1', 'customer' => 'cus_sub_1', 'status' => 'active' }
        expect {
          described_class.perform_now(event: event_for('customer.subscription.updated', sub))
          user.reload
        }.to change(user, :subscription_status).from('incomplete').to('active')
      end

      context "when re-subscribing after cancellation" do
        before { user.update!(subscription_status: 'canceled', subscription_canceled_at: 2.months.ago) }

        it "clears subscription_canceled_at when status becomes active" do
          sub = { 'id' => 'sub_reactiv', 'customer' => 'cus_sub_1', 'status' => 'active' }
          described_class.perform_now(event: event_for('customer.subscription.updated', sub))
          expect(user.reload.subscription_canceled_at).to be_nil
        end

        it "clears subscription_canceled_at when status becomes trialing" do
          sub = { 'id' => 'sub_reactiv', 'customer' => 'cus_sub_1', 'status' => 'trialing' }
          described_class.perform_now(event: event_for('customer.subscription.updated', sub))
          expect(user.reload.subscription_canceled_at).to be_nil
        end
      end

      it "updates stripe_subscription_id" do
        sub = { 'id' => 'sub_1', 'customer' => 'cus_sub_1', 'status' => 'active' }
        expect {
          described_class.perform_now(event: event_for('customer.subscription.updated', sub))
          user.reload
        }.to change(user, :stripe_subscription_id).from(nil).to('sub_1')
      end

      it "updates subscription_ends_at from current_period_end" do
        ts  = 2.days.from_now.to_i
        sub = { 'id' => 'sub_1', 'customer' => 'cus_sub_1', 'status' => 'active', 'current_period_end' => ts }
        described_class.perform_now(event: event_for('customer.subscription.updated', sub))
        expect(user.reload.subscription_ends_at).to be_within(1.second).of(Time.zone.at(ts))
      end

      it "updates subscription_ends_at from trial_end when trialing" do
        ts  = 7.days.from_now.to_i
        sub = { 'id' => 'sub_1', 'customer' => 'cus_sub_1', 'status' => 'trialing', 'trial_end' => ts }
        described_class.perform_now(event: event_for('customer.subscription.updated', sub))
        expect(user.reload.subscription_ends_at).to be_within(1.second).of(Time.zone.at(ts))
        expect(user.reload.subscription_status).to eq('trialing')
      end

      context "when all values are already up to date (idempotent)" do
        let(:ts) { 5.days.from_now }
        before { user.update!(subscription_status: 'active', stripe_subscription_id: 'sub_same', subscription_ends_at: ts) }

        it "does not change subscription_status" do
          sub = { 'id' => 'sub_same', 'customer' => 'cus_sub_1', 'status' => 'active', 'current_period_end' => ts.to_i }
          expect {
            described_class.perform_now(event: event_for('customer.subscription.updated', sub))
            user.reload
          }.not_to change(user, :subscription_status)
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # customer.subscription.deleted
  # ─────────────────────────────────────────────────────────────
  describe "customer.subscription.deleted" do
    context "when the subscription object is nil" do
      it "returns early without error" do
        expect {
          described_class.perform_now(event: event_for('customer.subscription.deleted', nil))
        }.not_to raise_error
      end
    end

    context "when no user matches" do
      it "returns early without error" do
        sub = { 'customer' => 'cus_ghost' }
        expect {
          described_class.perform_now(event: event_for('customer.subscription.deleted', sub))
        }.not_to raise_error
      end
    end

    context "when a matching user exists" do
      let!(:user) do
        create(:user, :subscribed, stripe_customer_id: 'cus_del_1', stripe_subscription_id: 'sub_old', subscription_ends_at: nil)
      end

      it "sets subscription_status to canceled" do
        sub = { 'customer' => 'cus_del_1' }
        expect {
          described_class.perform_now(event: event_for('customer.subscription.deleted', sub))
          user.reload
        }.to change(user, :subscription_status).to('canceled')
      end

      it "sets subscription_canceled_at to current time" do
        sub = { 'customer' => 'cus_del_1' }
        described_class.perform_now(event: event_for('customer.subscription.deleted', sub))
        expect(user.reload.subscription_canceled_at).to be_within(5.seconds).of(Time.current)
      end

      it "clears stripe_subscription_id" do
        sub = { 'customer' => 'cus_del_1' }
        expect {
          described_class.perform_now(event: event_for('customer.subscription.deleted', sub))
          user.reload
        }.to change(user, :stripe_subscription_id).from('sub_old').to(nil)
      end

      it "sets subscription_ends_at from ended_at" do
        ended_ts = 3.days.ago.to_i
        sub      = { 'customer' => 'cus_del_1', 'ended_at' => ended_ts }
        described_class.perform_now(event: event_for('customer.subscription.deleted', sub))
        expect(user.reload.subscription_ends_at).to be_within(1.second).of(Time.zone.at(ended_ts))
      end

      context "when already canceled (idempotent)" do
        before { user.update!(subscription_status: 'canceled', stripe_subscription_id: nil, subscription_canceled_at: 1.day.ago) }

        it "does not change subscription_status" do
          sub = { 'customer' => 'cus_del_1' }
          expect {
            described_class.perform_now(event: event_for('customer.subscription.deleted', sub))
            user.reload
          }.not_to change(user, :subscription_status)
        end

        it "does not overwrite subscription_canceled_at" do
          original_canceled_at = user.subscription_canceled_at
          sub = { 'customer' => 'cus_del_1' }
          described_class.perform_now(event: event_for('customer.subscription.deleted', sub))
          expect(user.reload.subscription_canceled_at).to be_within(1.second).of(original_canceled_at)
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # invoice.payment_failed
  # ─────────────────────────────────────────────────────────────
  describe "invoice.payment_failed" do
    context "when the invoice object is nil" do
      it "returns early without error" do
        expect {
          described_class.perform_now(event: event_for('invoice.payment_failed', nil))
        }.not_to raise_error
      end
    end

    context "when no user matches" do
      it "returns early without error" do
        invoice = { 'customer' => 'cus_ghost' }
        expect {
          described_class.perform_now(event: event_for('invoice.payment_failed', invoice))
        }.not_to raise_error
      end
    end

    context "when a matching user exists with active subscription" do
      let!(:user) { create(:user, :subscribed, stripe_customer_id: 'cus_inv_1') }

      it "marks the subscription as past_due" do
        invoice = { 'customer' => 'cus_inv_1' }
        expect {
          described_class.perform_now(event: event_for('invoice.payment_failed', invoice))
          user.reload
        }.to change(user, :subscription_status).from('active').to('past_due')
      end
    end

    context "when already past_due (idempotent)" do
      let!(:user) { create(:user, stripe_customer_id: 'cus_inv_2', subscription_status: 'past_due') }

      it "does not change subscription_status" do
        invoice = { 'customer' => 'cus_inv_2' }
        expect {
          described_class.perform_now(event: event_for('invoice.payment_failed', invoice))
          user.reload
        }.not_to change(user, :subscription_status)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Unknown event type
  # ─────────────────────────────────────────────────────────────
  describe "unknown event type" do
    it "does not raise and does not modify any user" do
      user = create(:user, :subscribed, stripe_customer_id: 'cus_unk')
      expect {
        described_class.perform_now(event: event_for('something.unexpected', { 'customer' => 'cus_unk' }))
      }.not_to raise_error
      expect(user.reload.subscription_status).to eq('active')
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Error handling — re-raises after logging
  # ─────────────────────────────────────────────────────────────
  describe "error handling" do
    it "re-raises exceptions that occur inside a handler" do
      session_data = {
        'customer'         => 'cus_err_1',
        'subscription'     => 'sub_err_1',
        'customer_details' => { 'email' => 'err@example.com' }
      }
      # Force an error inside handle_checkout_session_completed
      allow_any_instance_of(described_class)
        .to receive(:handle_checkout_session_completed)
        .and_raise(RuntimeError, "something broke")

      expect {
        described_class.perform_now(event: event_for('checkout.session.completed', session_data))
      }.to raise_error(RuntimeError, "something broke")
    end
  end
end
