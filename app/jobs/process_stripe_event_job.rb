# frozen_string_literal: true

class ProcessStripeEventJob < ApplicationJob
  queue_as :default

  # event: Hash representation of Stripe::Event
  def perform(event:)
    Rails.logger.info("[Stripe] Processing event in background: type=#{event['type']} id=#{event['id']}")

    case event['type']
    when 'checkout.session.completed'
      handle_checkout_session_completed(event.dig('data', 'object'))
    when 'customer.subscription.updated'
      handle_subscription_updated(event.dig('data', 'object'))
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.dig('data', 'object'))
    when 'invoice.payment_failed'
      handle_invoice_payment_failed(event.dig('data', 'object'))
    else
      Rails.logger.info("[Stripe] No handler implemented for event type #{event['type']}")
    end
  rescue => e
    Rails.logger.error("[Stripe] Failed processing event id=#{event['id']} type=#{event['type']} error=#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    raise
  end

  private

  def handle_checkout_session_completed(session)
    unless session
      Rails.logger.warn('[Stripe] Missing session object for checkout.session.completed')
      return
    end

    customer_id = session['customer'] || session['customer_id']
    subscription_id = session['subscription']

    if customer_id.blank?
      Rails.logger.warn("[Stripe] checkout.session.completed missing customer id in session id=#{session['id']}")
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] checkout.session.completed: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    attrs = {}
    attrs[:stripe_subscription_id] = subscription_id if subscription_id.present? && user.stripe_subscription_id != subscription_id
    attrs[:subscription_status] = 'active' if user.subscription_status != 'active'

    if attrs.any?
      user.update!(attrs)
      Rails.logger.info("[Stripe] Activated subscription for user_id=#{user.id} stripe_subscription_id=#{user.stripe_subscription_id}")
    else
      Rails.logger.info("[Stripe] checkout.session.completed: no changes for user_id=#{user.id}")
    end
  rescue => e
    Rails.logger.error("[Stripe] Error handling checkout.session.completed: #{e.class} #{e.message}")
    raise
  end

  def handle_subscription_updated(sub)
    unless sub
      Rails.logger.warn('[Stripe] Missing subscription object for customer.subscription.updated')
      return
    end

    customer_id = sub['customer']
    if customer_id.blank?
      Rails.logger.warn('[Stripe] customer.subscription.updated missing customer id')
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] customer.subscription.updated: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    new_status = sub['status']
    current_period_end = sub['current_period_end']
    trial_end = sub['trial_end']

    attrs = {}
    attrs[:subscription_status] = new_status if new_status.present? && user.subscription_status != new_status

    if current_period_end.present?
      ends_at = Time.zone.at(current_period_end.to_i)
      attrs[:subscription_ends_at] = ends_at if user.subscription_ends_at != ends_at
    end

    if trial_end.present? && new_status == 'trialing'
      trial_ends_at = Time.zone.at(trial_end.to_i)
      attrs[:subscription_ends_at] = trial_ends_at if user.subscription_ends_at != trial_ends_at
    end

    if sub['id'].present? && user.stripe_subscription_id != sub['id']
      attrs[:stripe_subscription_id] = sub['id']
    end

    if attrs.any?
      user.update!(attrs)
      Rails.logger.info("[Stripe] Updated subscription for user_id=#{user.id} status=#{user.subscription_status} ends_at=#{user.subscription_ends_at}")
    else
      Rails.logger.info("[Stripe] customer.subscription.updated: no changes for user_id=#{user.id}")
    end
  rescue => e
    Rails.logger.error("[Stripe] Error handling customer.subscription.updated: #{e.class} #{e.message}")
    raise
  end

  def handle_subscription_deleted(sub)
    unless sub
      Rails.logger.warn('[Stripe] Missing subscription object for customer.subscription.deleted')
      return
    end

    customer_id = sub['customer']
    if customer_id.blank?
      Rails.logger.warn('[Stripe] customer.subscription.deleted missing customer id')
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] customer.subscription.deleted: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    attrs = {}
    attrs[:subscription_status] = 'canceled' unless user.subscription_status == 'canceled'

    if sub['ended_at'].present?
      ended_at = Time.zone.at(sub['ended_at'].to_i)
      attrs[:subscription_ends_at] = ended_at if user.subscription_ends_at != ended_at
    end

    if user.stripe_subscription_id.present?
      attrs[:stripe_subscription_id] = nil
    end

    if attrs.any?
      user.update!(attrs)
      Rails.logger.info("[Stripe] Canceled subscription for user_id=#{user.id} ended_at=#{user.subscription_ends_at}")
    else
      Rails.logger.info("[Stripe] customer.subscription.deleted: no changes for user_id=#{user.id}")
    end
  rescue => e
    Rails.logger.error("[Stripe] Error handling customer.subscription.deleted: #{e.class} #{e.message}")
    raise
  end

  def handle_invoice_payment_failed(invoice)
    unless invoice
      Rails.logger.warn('[Stripe] Missing invoice object for invoice.payment_failed')
      return
    end

    customer_id = invoice['customer']
    if customer_id.blank?
      Rails.logger.warn('[Stripe] invoice.payment_failed missing customer id')
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] invoice.payment_failed: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    if user.subscription_status != 'past_due'
      user.update!(subscription_status: 'past_due')
      Rails.logger.info("[Stripe] Marked subscription past_due for user_id=#{user.id}")
    else
      Rails.logger.info("[Stripe] invoice.payment_failed: user already past_due user_id=#{user.id}")
    end

    if defined?(UserMailer) && UserMailer.respond_to?(:subscription_payment_failed)
      UserMailer.subscription_payment_failed(user).deliver_later
      Rails.logger.info("[Stripe] Enqueued subscription payment failed email for user_id=#{user.id}")
    else
      Rails.logger.info("[Stripe] No mailer configured to send payment failed email for user_id=#{user.id}")
    end
  rescue => e
    Rails.logger.error("[Stripe] Error handling invoice.payment_failed: #{e.class} #{e.message}")
    raise
  end
end
