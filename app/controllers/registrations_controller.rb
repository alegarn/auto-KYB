class RegistrationsController < ApplicationController

  skip_before_action :authenticate, only: %i[new create]

  def new
    @user = User.new
    render inertia: "registrations/new", props: { user: @user }
  end

  def create
    @user = User.new(user_params)

    if @user.save
      send_email_verification

      # Create a session for the newly registered user (log them in)
      @session = @user.sessions.create!
      cookies.permanent.signed[:session_token] = @session.id

      # Create Stripe Checkout Session and return URL to frontend (or redirect for HTML)
      price_id = ENV['STRIPE_BASIC_PLAN_PRICE_ID']
      unless price_id.present?
        Rails.logger.error("Stripe: missing STRIPE_BASIC_PLAN_PRICE_ID")
        respond_to do |format|
          format.json { render json: { error: 'Pricing not configured' }, status: :unprocessable_entity }
          format.html { redirect_to sign_in_path, notice: "Welcome! Check your email to verify your account" }
        end
        return
      end

      begin
        if @user.stripe_customer_id.blank?
          customer = Stripe::Customer.create(email: @user.email, metadata: { user_id: @user.id })
          @user.update!(stripe_customer_id: customer.id)
        end

        checkout_session = Stripe::Checkout::Session.create(
          mode: 'subscription',
          customer: @user.stripe_customer_id,
          line_items: [ { price: price_id, quantity: 1 } ],
          success_url: checkout_sessions_success_url + '?session_id={CHECKOUT_SESSION_ID}',
          cancel_url: checkout_sessions_cancel_url,
          metadata: { user_id: @user.id }
        )

        respond_to do |format|
          format.json { render json: { url: checkout_session.url }, status: :created }
          format.html { redirect_to checkout_session.url }
        end
      rescue Stripe::StripeError => e
        Rails.logger.error("Stripe error creating checkout session for user=#{@user&.id}: #{e.message}")
        respond_to do |format|
          format.json { render json: { error: 'Payment provider error' }, status: :bad_gateway }
          format.html { redirect_to sign_in_path, alert: 'Payment provider error' }
        end
      rescue => e
        Rails.logger.error("Registrations#create unexpected error: #{e.class} #{e.message}")
        respond_to do |format|
          format.json { render json: { error: 'Internal server error' }, status: :internal_server_error }
          format.html { redirect_to sign_in_path, alert: 'Internal server error' }
        end
      end

    else
      flash.now.inertia[:alert] = "There was an error with your registration"
      respond_to do |format|
        format.json { render json: { errors: @user.errors }, status: :unprocessable_entity }
        format.html { render inertia: "registrations/new", props: { user: @user }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    unless params[:confirmation].to_s == "DELETE"
      redirect_to settings_path,
                  alert: "Please type DELETE to confirm account deletion.",
                  status: :see_other
      return
    end

    current_user.destroy!
    cookies.delete(:session_token)
    Current.session = nil

    redirect_to root_path,
                notice: "Your account has been deleted.",
                status: :see_other
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to settings_path,
                alert: "We could not delete your account. Please try again.",
                status: :see_other
  end

  private
    def user_params
      # Accept either top-level params or nested under :registration
      source = params[:registration] || params
      permitted = source.permit(:email)

      result = {}
      result[:email] = permitted[:email] if permitted[:email].present?

      result
    end

    def send_email_verification
      UserMailer.with(user: @user).email_verification.deliver_later
    end

end
