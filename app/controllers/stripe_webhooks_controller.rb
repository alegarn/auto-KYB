# frozen_string_literal: true

class StripeWebhooksController < ApplicationController
  # Webhook endpoints are called by Stripe; disable CSRF and authentication
  skip_before_action :verify_authenticity_token
  skip_before_action :set_current_user
  skip_before_action :authenticate
  before_action :skip_authorization

  # POST /webhooks/stripe
  def create
    payload = request.raw_post
    sig_header = request.env['HTTP_STRIPE_SIGNATURE'] || request.headers['Stripe-Signature']
    secrets = webhook_secrets

    Rails.logger.info("[Stripe] Webhook received; sig_header_present=#{sig_header.present?}")

    if secrets.empty?
      Rails.logger.error("[Stripe] STRIPE_WEBHOOK_SECRET is not configured")
      head :internal_server_error and return
    end

    begin
      event = construct_event(payload, sig_header, secrets)

      Rails.logger.info("[Stripe] Received event: type=#{event.type} id=#{event.id}")

      case event.type
      when 'checkout.session.completed',
           'customer.subscription.updated',
           'customer.subscription.deleted',
           'invoice.payment_failed',
           'invoice.paid'
        # Delegate actual processing to background job for performance
        # The job should inspect event.to_h and act accordingly.
        ProcessStripeEventJob.perform_later(event: JSON.parse(event.to_json))
      else
        Rails.logger.info("[Stripe] Ignoring unsupported event type: #{event.type}")
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.warn("[Stripe] Invalid payload: #{e.message}")
      head :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.warn("[Stripe] Signature verification failed: #{e.message}")
      head :bad_request
    rescue => e
      Rails.logger.error("[Stripe] Unexpected error while handling webhook: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}")
      head :internal_server_error
    end
  end

  private

    def construct_event(payload, sig_header, secrets)
      last_error = nil

      secrets.each do |secret|
        return Stripe::Webhook.construct_event(payload, sig_header, secret)
      rescue Stripe::SignatureVerificationError => e
        last_error = e
      end

      raise last_error if last_error
    end

    def webhook_secrets
      [
        Rails.application.credentials.dig(:stripe, :webhook_secret) || ENV['STRIPE_WEBHOOK_SECRET'],
        ENV['STRIPE_WEBHOOK_SECRET']
      ].filter_map { |secret| secret&.strip&.presence }.uniq
    end
end
