# frozen_string_literal: true

# Runs daily via config/recurring.yml.
# Hard-deletes user accounts that have been in a "canceled" state for more than 1 year.
# The cascade on sessions/forms/clients in the DB ensures all related data is removed.
class PurgeCanceledAccountsJob < ApplicationJob

  queue_as :default

  def perform
    scope = User.where("subscription_canceled_at <= ?", 1.year.ago)
    count = scope.count

    if count.zero?
      Rails.logger.info("[PurgeCanceledAccountsJob] No expired accounts to purge.")
      return
    end

    Rails.logger.info("[PurgeCanceledAccountsJob] Purging #{count} expired canceled account(s).")
    scope.find_each do |user|
      cancel_stripe_subscription_for(user)
      user.destroy!
      Rails.logger.info("[PurgeCanceledAccountsJob] Destroyed user_id=#{user.id}")
    rescue => e
      Rails.logger.error("[PurgeCanceledAccountsJob] Failed to destroy user_id=#{user.id}: #{e.class} #{e.message}")
    end
  end

  private

  def cancel_stripe_subscription_for(user)
    return unless user.stripe_subscription_id.present?

    Stripe::Subscription.cancel(user.stripe_subscription_id)
  rescue Stripe::InvalidRequestError => e
    # Already canceled or not found — safe to continue
    Rails.logger.warn("[PurgeCanceledAccountsJob] Stripe cancel skipped for user_id=#{user.id}: #{e.message}")
  end

end
