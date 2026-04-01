# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Inertia Shared Auth State", type: :request, inertia: true do
  def stub_crm_transfer_signals_query(expected_payloads, &block)
    query_class = class_double("CrmTransferSignalsQuery").as_stubbed_const

    allow(query_class).to receive(:new) do |*args, **kwargs|
      params = kwargs.empty? ? args.fetch(0) : kwargs
      user = params.fetch(:user)
      toast_seen_at = params[:toast_seen_at]

      block&.call(user:, toast_seen_at:)

      payload = expected_payloads.fetch(toast_seen_at) do
        raise "Unexpected toast_seen_at: #{toast_seen_at.inspect}"
      end

      instance_double("CrmTransferSignalsQuery", call: payload)
    end
  end

  describe "inertia_share :auth" do
    context "when the user is not authenticated" do
      it "shares auth: nil" do
        get sign_in_path
        expect(inertia.props[:auth]).to be_nil
      end

      it "shares crm_transfer_signals: nil" do
        get sign_in_path
        expect(inertia.props[:crm_transfer_signals]).to be_nil
      end
    end

    context "when the user is authenticated with an active subscription" do
      let(:user) { create(:user, :subscribed, plan: 'pro') }
      let(:latest_unread_failure_at) { 5.minutes.ago.iso8601 }
      let(:query_payload) do
        {
          unread_failed_count: 2,
          unread_retryable_count: 1,
          latest_unread_failure_at: latest_unread_failure_at,
          toast: {
            type: "alert",
            message: "2 CRM transfers failed. Review them on CRM Transfers.",
            href: "/crm_transfers?status=failed"
          }
        }
      end
      let(:query_payload_without_toast) { query_payload.merge(toast: nil) }
      let(:session_record) { user.sessions.create! }

      before do
        stub_crm_transfer_signals_query(
          nil => query_payload,
          latest_unread_failure_at => query_payload_without_toast
        )

        cookies["session_token"] = session_record.id
        get dashboard_path
      end

      it "shares auth.user.email" do
        expect(inertia.props.dig(:auth, :user, :email)).to eq(user.email)
      end

      it "shares auth.subscription.active as true" do
        expect(inertia.props.dig(:auth, :subscription, :active)).to be true
      end

      it "shares auth.subscription.status as active" do
        expect(inertia.props.dig(:auth, :subscription, :status)).to eq("active")
      end

      it "shares auth.subscription.canceled_at as nil" do
        expect(inertia.props.dig(:auth, :subscription, :canceled_at)).to be_nil
      end

      it "shares auth.user.onboarding_completed" do
        expect(inertia.props.dig(:auth, :user, :onboarding_completed)).to eq(user.onboarding_completed)
      end

      it "shares auth.features.crm entitlement" do
        expect(inertia.props.dig(:auth, :features, :crm, :allowed)).to be true
        expect(inertia.props.dig(:auth, :features, :crm, :reason)).to eq("allowed")
      end

      it "shares crm_transfer_signals from the query" do
        expect(inertia.props.dig(:crm_transfer_signals)).to eq(query_payload)
      end

      it "advances the toast session marker after sharing a toast" do
        expect(session[:crm_transfer_failure_toast_seen_at]).to eq(latest_unread_failure_at)
      end

      it "passes the session toast marker on the next request" do
        get dashboard_path
        expect(inertia.props.dig(:crm_transfer_signals, :toast)).to be_nil
        expect(session[:crm_transfer_failure_toast_seen_at]).to eq(latest_unread_failure_at)
      end
    end

    context "when the user has a canceled subscription" do
      let(:canceled_at) { 1.month.ago }
      let(:user) { create(:user, :canceled, subscription_canceled_at: canceled_at) }

      before do
        session_record = user.sessions.create!
        cookies["session_token"] = session_record.id
        get subscription_required_path
      end

      it "shares auth.subscription.active as false" do
        expect(inertia.props.dig(:auth, :subscription, :active)).to be false
      end

      it "shares auth.subscription.canceled_at as ISO8601 string" do
        expect(inertia.props.dig(:auth, :subscription, :canceled_at)).to be_a(String)
      end

      it "shares auth.features.crm entitlement" do
        expect(inertia.props.dig(:auth, :features, :crm, :allowed)).to be false
        expect(inertia.props.dig(:auth, :features, :crm, :reason)).to eq("subscription_inactive")
      end
    end
  end
end
