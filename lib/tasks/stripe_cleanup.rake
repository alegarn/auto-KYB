# frozen_string_literal: true

namespace :stripe do
  desc "Clean up placeholder users created by Stripe webhooks who never completed registration"
  task cleanup_placeholder_users: :environment do
    # Find users who have a stripe_customer_id but no password_digest
    # Wait, Google OAuth users also have a password_digest because of the before_validation callback.
    # How do we identify placeholder users?
    # Placeholder users are created in ProcessStripeEventJob with:
    # user = User.new(email: email, stripe_customer_id: customer_id, stripe_subscription_id: subscription_id, subscription_status: 'active')
    # But wait, they are NOT saved in the database!
    # Let's check ProcessStripeEventJob.
  end
end
