class CheckoutSessionsController < ApplicationController

  skip_before_action :authenticate, only: [ :create, :success, :cancel ]
  before_action :skip_authorization

  # Creates a Stripe Checkout Session
  def create
    plan_param = params[:plan] == 'pro' ? 'pro' : 'basic'
    price_id = if plan_param == 'pro'
      Rails.application.credentials.dig(:stripe, :pro_plan_price_id) || ENV['STRIPE_PRO_PLAN_PRICE_ID']
    else
      Rails.application.credentials.dig(:stripe, :basic_plan_price_id) || ENV['STRIPE_BASIC_PLAN_PRICE_ID']
    end

    unless price_id.present?
      Rails.logger.error("Stripe: missing STRIPE_#{plan_param.upcase}_PLAN_PRICE_ID")
      return render json: { error: 'Pricing not configured' }, status: :unprocessable_entity
    end

    # We no longer require an authenticated user.
    # If an email is provided, we pass it to Stripe to pre-fill the checkout form.
    customer_email = params[:email]

    begin
      session_params = {
        mode: 'subscription',
        line_items: [ { price: price_id, quantity: 1 } ],
        success_url: complete_registration_url + '?session_id={CHECKOUT_SESSION_ID}',
        cancel_url: checkout_sessions_cancel_url,
      }

      # Pre-fill email if provided
      session_params[:customer_email] = customer_email if customer_email.present?

      # If the user is already logged in (e.g., upgrading from a canceled state), use their customer ID
      if Current.user
        if Current.user.stripe_customer_id.blank?
          customer = Stripe::Customer.create(email: Current.user.email, metadata: { user_id: Current.user.id })
          Current.user.update!(stripe_customer_id: customer.id)
        end
        session_params.delete(:customer_email)
        session_params[:customer] = Current.user.stripe_customer_id
        session_params[:metadata] = { user_id: Current.user.id }
      end

      session = Stripe::Checkout::Session.create(session_params)

      render json: { url: session.url }, status: :created
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error creating checkout session: #{e.message}")
      render json: { error: 'Payment provider error' }, status: :bad_gateway
    rescue => e
      Rails.logger.error("CheckoutSessions#create unexpected error: #{e.class} #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  # Renders thank you page after successful payment
  def success
    # This is now handled by RegistrationsController#complete
    # But we keep this for legacy or other flows if needed, or redirect to complete
    if params[:session_id].present?
      redirect_to complete_registration_path(session_id: params[:session_id])
    else
      redirect_to sign_in_path, notice: "If you just completed a payment, please check your email for a login link."
    end
  end

  # Renders cancelled payment page
  def cancel
    render inertia: "CheckoutSessions/Cancel", props: { user: Current.user }
  end

end
