class SubscriptionsController < ApplicationController

  skip_before_action :authenticate, only: [ :required ]

  # Renders a page informing the user they need an active subscription
  def required
    skip_authorization
    render inertia: "Subscription/Required", props: { user: Current.user }
  end

  # Creates a Stripe Billing Portal session for the current user and returns
  # the portal URL as JSON. Expects the user to be authenticated.
  def billing_portal
    authorize :subscription, :billing_portal?
    user = current_user

    begin
      customer_id = ensure_stripe_customer_id!(user)
      session = create_billing_portal_session(customer_id)

      render json: { url: session.url }, status: :created
    rescue Stripe::InvalidRequestError => e
      if missing_customer_error?(e)
        Rails.logger.warn("Stripe billing portal: stale customer_id for user=#{user.id}. Recreating customer.")
        customer = Stripe::Customer.create(email: user.email, metadata: { user_id: user.id })
        user.update!(stripe_customer_id: customer.id)

        session = create_billing_portal_session(customer.id)
        return render json: { url: session.url }, status: :created
      end

      Rails.logger.error("Stripe invalid request creating billing portal for user=#{user.id}: #{e.message}")
      render json: { error: "Payment provider error" }, status: :bad_gateway
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error creating billing portal for user=#{user.id}: #{e.message}")
      render json: { error: "Payment provider error" }, status: :bad_gateway
    rescue => e
      Rails.logger.error("Subscriptions#billing_portal unexpected error: #{e.class} #{e.message}")
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end

  private

  def ensure_stripe_customer_id!(user)
    return user.stripe_customer_id if user.stripe_customer_id.present?

    customer = Stripe::Customer.create(email: user.email, metadata: { user_id: user.id })
    user.update!(stripe_customer_id: customer.id)
    customer.id
  end

  def create_billing_portal_session(customer_id)
    params = {
      customer: customer_id,
      return_url: settings_url
    }

    configuration_id = ENV["STRIPE_BILLING_PORTAL_CONFIGURATION_ID"]
    params[:configuration] = configuration_id if configuration_id.present?

    Stripe::BillingPortal::Session.create(params)
  end

  def missing_customer_error?(error)
    return false unless error.respond_to?(:message)

    message = error.message.to_s.downcase
    message.include?("no such customer") || message.include?("customer does not exist")
  end

end
