class CheckoutSessionsController < ApplicationController
  before_action :ensure_authenticated

  # Creates a Stripe Checkout Session for the current user
  def create
    price_id = ENV['STRIPE_BASIC_PLAN_PRICE_ID']
    unless price_id.present?
      Rails.logger.error("Stripe: missing STRIPE_BASIC_PLAN_PRICE_ID")
      return render json: { error: 'Pricing not configured' }, status: :unprocessable_entity
    end

    user = Current.user
    unless user
      return render json: { error: 'Not authenticated' }, status: :unauthorized
    end

    begin
      if user.stripe_customer_id.blank?
        customer = Stripe::Customer.create(email: user.email, metadata: { user_id: user.id })
        user.update!(stripe_customer_id: customer.id)
      end

      session = Stripe::Checkout::Session.create(
        mode: 'subscription',
        customer: user.stripe_customer_id,
        line_items: [ { price: price_id, quantity: 1 } ],
        success_url: checkout_sessions_success_url + '?session_id={CHECKOUT_SESSION_ID}',
        cancel_url: checkout_sessions_cancel_url,
        metadata: { user_id: user.id }
      )

      render json: { url: session.url }, status: :created
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error creating checkout session for user=#{user&.id}: #{e.message}")
      render json: { error: 'Payment provider error' }, status: :bad_gateway
    rescue => e
      Rails.logger.error("CheckoutSessions#create unexpected error: #{e.class} #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  # Renders thank you page after successful payment
  def success
    render inertia: "CheckoutSessions/Success", props: { user: Current.user }
  end

  # Renders cancelled payment page
  def cancel
    render inertia: "CheckoutSessions/Cancel", props: { user: Current.user }
  end

  private

  def ensure_authenticated
    return if Current.user

    respond_to do |format|
      format.json { render json: { error: 'Not authenticated' }, status: :unauthorized }
      format.html { redirect_to sign_in_path }
    end
  end
end
