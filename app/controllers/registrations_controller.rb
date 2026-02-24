class RegistrationsController < ApplicationController

  skip_before_action :authenticate, only: %i[new complete finalize]

  def new
    @user = User.new
    render inertia: "registrations/new", props: { 
      user: @user,
      stripe_publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
      stripe_pricing_table_id: ENV['STRIPE_PRICING_TABLE_ID'],
      customer_email: Current.user&.email
    }
  end

  def complete
    session_id = params[:session_id]
    if session_id.blank?
      return redirect_to sign_up_path, alert: "Invalid session."
    end

    begin
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)
      if checkout_session.payment_status != 'paid'
        return redirect_to sign_up_path, alert: "Payment not completed."
      end

      customer_id = checkout_session.customer
      user = User.find_by(stripe_customer_id: customer_id)
      
      if user && user.password_digest.present? && user.sessions.any?
         # User already fully registered
         redirect_to sign_in_path, notice: "Account already created. Please sign in."
         return
      end

      email = checkout_session.customer_details&.email
      render inertia: "registrations/Complete", props: { email: email, session_id: session_id }
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error retrieving session: #{e.message}")
      redirect_to sign_up_path, alert: "Unable to verify payment."
    end
  end

  def finalize
    session_id = params[:session_id]
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    begin
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)
      if checkout_session.payment_status != 'paid'
        return render json: { error: "Payment not completed." }, status: :unprocessable_entity
      end

      customer_id = checkout_session.customer
      email = checkout_session.customer_details&.email
      subscription_id = checkout_session.subscription

      user = User.find_or_initialize_by(stripe_customer_id: customer_id)
      user.email = email
      user.password = password
      user.password_confirmation = password_confirmation
      user.stripe_subscription_id = subscription_id
      user.subscription_status = 'active'
      user.verified = true # Since they paid via Stripe, we can consider their email verified

      if user.save
        # Log them in
        @session = user.sessions.create!
        cookies.permanent.signed[:session_token] = @session.id
        
        render json: { redirect_url: dashboard_path }, status: :created
      else
        render json: { errors: user.errors }, status: :unprocessable_entity
      end
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error finalizing registration: #{e.message}")
      render json: { error: "Payment verification failed." }, status: :bad_gateway
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
