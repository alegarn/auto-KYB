class SubscriptionsController < ApplicationController
  skip_before_action :authenticate, only: [:required]

  # Renders a page informing the user they need an active subscription
  def required
    render inertia: "Subscription/Required", props: { user: Current.user }
  end

  # Creates a Stripe Billing Portal session for the current user and returns
  # the portal URL as JSON. Expects the user to be authenticated.
  def billing_portal
    user = Current.user

    unless user
      return render json: { error: 'Not authenticated' }, status: :unauthorized
    end

    if user.stripe_customer_id.blank?
      return render json: { error: 'No payment account found for user' }, status: :unprocessable_entity
    end

    begin
      session = Stripe::BillingPortal::Session.create(
        customer: user.stripe_customer_id,
        return_url: settings_url
      )

      render json: { url: session.url }, status: :created
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error creating billing portal for user=#{user.id}: #{e.message}")
      render json: { error: 'Payment provider error' }, status: :bad_gateway
    rescue => e
      Rails.logger.error("Subscriptions#billing_portal unexpected error: #{e.class} #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end
end
