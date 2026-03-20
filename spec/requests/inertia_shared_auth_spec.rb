# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Inertia Shared Auth State", type: :request do
  let(:inertia_headers) { { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest } }

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
        get sign_in_path, headers: inertia_headers
        json = JSON.parse(response.body)
        expect(json.dig("props", "auth")).to be_nil
      end

      it "shares crm_transfer_signals: nil" do
        get sign_in_path, headers: inertia_headers
        json = JSON.parse(response.body)

        expect(json.dig("props", "crm_transfer_signals")).to be_nil
      end
    end

    context "when the user is authenticated with an active subscription" do
      let(:user) { create(:user, :subscribed) }
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
      let(:auth_headers) do
        inertia_headers.merge(
          "Cookie" => "session_token=#{session_record.id}"
        )
      end

      before do
        stub_crm_transfer_signals_query(
          nil => query_payload,
          latest_unread_failure_at => query_payload_without_toast
        )

        get dashboard_path, headers: auth_headers
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

      it "shares crm_transfer_signals from the query" do
        json = JSON.parse(response.body)

        expect(json.dig("props", "crm_transfer_signals")).to eq(
          JSON.parse(query_payload.to_json)
        )
      end

      it "advances the toast session marker after sharing a toast" do
        expect(session[:crm_transfer_failure_toast_seen_at]).to eq(latest_unread_failure_at)
      end

      it "passes the session toast marker on the next request" do
        session_cookie_key = Rails.application.config.session_options[:key]
        session_cookie = response.headers.fetch("Set-Cookie").split("\n").find do |cookie|
          cookie.start_with?(session_cookie_key)
        end
        second_request_headers = inertia_headers.merge(
          "Cookie" => [
            "session_token=#{session_record.id}",
            session_cookie&.split(';')&.first
          ].compact.join('; ')
        )

        get dashboard_path, headers: second_request_headers

        json = JSON.parse(response.body)

        expect(json.dig("props", "crm_transfer_signals", "toast")).to be_nil
        expect(session[:crm_transfer_failure_toast_seen_at]).to eq(latest_unread_failure_at)
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
