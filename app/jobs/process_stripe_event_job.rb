# frozen_string_literal: true

class ProcessStripeEventJob < ApplicationJob

  queue_as :default

  # event: Hash representation of Stripe::Event
  def perform(event:)
    Rails.logger.info("[Stripe] Processing event in background: type=#{event['type']} id=#{event['id']}")

    case event["type"]
    when "checkout.session.completed"
      handle_checkout_session_completed(event.dig("data", "object"), event["created"])
    when "customer.subscription.updated"
      handle_subscription_updated(event.dig("data", "object"), event["created"])
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.dig("data", "object"), event["created"])
    when "invoice.payment_failed"
      handle_invoice_payment_failed(event.dig("data", "object"), event["created"])
    when "invoice.paid"
      handle_invoice_paid(event.dig("data", "object"), event["created"])
    else
      Rails.logger.info("[Stripe] No handler implemented for event type #{event['type']}")
    end
  rescue => e
    Rails.logger.error("[Stripe] Failed processing event id=#{event['id']} type=#{event['type']} error=#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    raise
  end

  private

  def stale_event?(user, event_ts)
    return false if event_ts.nil?
    return false if user.last_stripe_event_ts.nil?

    if event_ts < user.last_stripe_event_ts
      Rails.logger.info("[Stripe] Skipping stale event for user_id=#{user.id}: event_ts=#{event_ts} < last_stripe_event_ts=#{user.last_stripe_event_ts}")
      return true
    end
    false
  end

  def handle_checkout_session_completed(session, event_ts = nil)
    unless session
      Rails.logger.warn("[Stripe] Missing session object for checkout.session.completed")
      return
    end

    customer_id = session["customer"] || session["customer_id"]
    subscription_id = session["subscription"]
    email = session.dig("customer_details", "email")

    if customer_id.blank?
      Rails.logger.warn("[Stripe] checkout.session.completed missing customer id in session id=#{session['id']}")
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)

    if user.nil?
      # In the "Pay First" flow, the user might not exist yet if they haven't completed the frontend registration step.
      # We create a placeholder user here to ensure we don't lose the subscription link if they close the browser.
      Rails.logger.info("[Stripe] checkout.session.completed: user not found for stripe_customer_id=#{customer_id}. Creating placeholder.")

      user = User.create!(
        email: email,
        stripe_customer_id: customer_id,
        stripe_subscription_id: subscription_id,
        subscription_status: "active",
        verified: true,
        last_stripe_event_ts: event_ts
      )

      # Send an email to the user with a link to complete their registration
      UserMailer.with(user: user).passwordless.deliver_later
      return
    end

    return if stale_event?(user, event_ts)

    attrs = {}
    attrs[:last_stripe_event_ts] = event_ts if event_ts && (user.last_stripe_event_ts.nil? || event_ts >= user.last_stripe_event_ts)
    attrs[:stripe_subscription_id] = subscription_id if subscription_id.present? && user.stripe_subscription_id != subscription_id
    attrs[:subscription_status] = "active" if user.subscription_status != "active"

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

  def handle_subscription_updated(sub, event_ts = nil)
    unless sub
      Rails.logger.warn("[Stripe] Missing subscription object for customer.subscription.updated")
      return
    end

    customer_id = sub["customer"]
    if customer_id.blank?
      Rails.logger.warn("[Stripe] customer.subscription.updated missing customer id")
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] customer.subscription.updated: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    return if stale_event?(user, event_ts)

    new_status = sub["status"]
    current_period_end = sub["current_period_end"]
    trial_end = sub["trial_end"]

    attrs = {}
    attrs[:last_stripe_event_ts] = event_ts if event_ts && (user.last_stripe_event_ts.nil? || event_ts >= user.last_stripe_event_ts)
    attrs[:subscription_status] = new_status if new_status.present? && user.subscription_status != new_status

    # Clear subscription_canceled_at on reactivation so the 1-year purge window resets
    if new_status.in?(%w[active trialing]) && user.subscription_canceled_at.present?
      attrs[:subscription_canceled_at] = nil
    end

    if current_period_end.present?
      ends_at = Time.zone.at(current_period_end.to_i)
      attrs[:subscription_ends_at] = ends_at if user.subscription_ends_at != ends_at
    end

    if trial_end.present? && new_status == "trialing"
      trial_ends_at = Time.zone.at(trial_end.to_i)
      attrs[:subscription_ends_at] = trial_ends_at if user.subscription_ends_at != trial_ends_at
    end

    if sub["id"].present? && user.stripe_subscription_id != sub["id"]
      attrs[:stripe_subscription_id] = sub["id"]
    end

    if sub["items"] && sub["items"]["data"].present?
      price_id = sub["items"]["data"].first&.dig("price", "id")
      if price_id == ENV["STRIPE_PRO_PLAN_PRICE_ID"] && price_id.present?
        attrs[:plan] = "pro"
      elsif price_id == ENV["STRIPE_BASIC_PLAN_PRICE_ID"] && price_id.present?
        attrs[:plan] = "basic"
      end
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

  def handle_subscription_deleted(sub, event_ts = nil)
    unless sub
      Rails.logger.warn("[Stripe] Missing subscription object for customer.subscription.deleted")
      return
    end

    customer_id = sub["customer"]
    if customer_id.blank?
      Rails.logger.warn("[Stripe] customer.subscription.deleted missing customer id")
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] customer.subscription.deleted: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    return if stale_event?(user, event_ts)

    attrs = {}
    attrs[:last_stripe_event_ts] = event_ts if event_ts && (user.last_stripe_event_ts.nil? || event_ts >= user.last_stripe_event_ts)
    attrs[:subscription_status] = "canceled" unless user.subscription_status == "canceled"
    attrs[:subscription_canceled_at] = Time.current if user.subscription_canceled_at.nil?

    if sub["ended_at"].present?
      ended_at = Time.zone.at(sub["ended_at"].to_i)
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

  def handle_invoice_payment_failed(invoice, event_ts = nil)
    unless invoice
      Rails.logger.warn("[Stripe] Missing invoice object for invoice.payment_failed")
      return
    end

    customer_id = invoice["customer"]
    if customer_id.blank?
      Rails.logger.warn("[Stripe] invoice.payment_failed missing customer id")
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] invoice.payment_failed: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    return if stale_event?(user, event_ts)

    attrs = {}
    attrs[:last_stripe_event_ts] = event_ts if event_ts && (user.last_stripe_event_ts.nil? || event_ts >= user.last_stripe_event_ts)

    if user.subscription_status != "past_due"
      attrs[:subscription_status] = "past_due"
      user.update!(attrs)
      Rails.logger.info("[Stripe] Marked subscription past_due for user_id=#{user.id}")
    else
      user.update!(attrs) if attrs.any?
      Rails.logger.info("[Stripe] invoice.payment_failed: user already past_due user_id=#{user.id}")
    end

    UserMailer.with(user: user).subscription_payment_failed.deliver_later
    Rails.logger.info("[Stripe] Enqueued subscription payment failed email for user_id=#{user.id}")
  rescue => e
    Rails.logger.error("[Stripe] Error handling invoice.payment_failed: #{e.class} #{e.message}")
    raise
  end

  def handle_invoice_paid(invoice, event_ts = nil)
    unless invoice
      Rails.logger.warn("[Stripe] Missing invoice object for invoice.paid")
      return
    end

    # Only handle subscription invoices (ignore one-time charges)
    return if invoice["subscription"].blank?

    customer_id = invoice["customer"]
    if customer_id.blank?
      Rails.logger.warn("[Stripe] invoice.paid missing customer id")
      return
    end

    user = User.find_by(stripe_customer_id: customer_id)
    unless user
      Rails.logger.warn("[Stripe] invoice.paid: user not found for stripe_customer_id=#{customer_id}")
      return
    end

    return if stale_event?(user, event_ts)

    attrs = {}
    attrs[:last_stripe_event_ts] = event_ts if event_ts && (user.last_stripe_event_ts.nil? || event_ts >= user.last_stripe_event_ts)

    # Recover from past_due: Stripe also fires customer.subscription.updated, but
    # handling invoice.paid explicitly lets us send a recovery notification.
    if user.subscription_status == "past_due"
      attrs[:subscription_status] = "active"
      user.update!(attrs)
      Rails.logger.info("[Stripe] Recovered subscription from past_due for user_id=#{user.id}")
      UserMailer.with(user: user).subscription_payment_recovered.deliver_later
      Rails.logger.info("[Stripe] Enqueued payment recovered email for user_id=#{user.id}")
    else
      user.update!(attrs) if attrs.any?
      Rails.logger.info("[Stripe] invoice.paid: no status change needed for user_id=#{user.id} status=#{user.subscription_status}")
    end
  rescue => e
    Rails.logger.error("[Stripe] Error handling invoice.paid: #{e.class} #{e.message}")
    raise
  end

end
