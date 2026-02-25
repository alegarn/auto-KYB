class RegistrationsController < ApplicationController

  skip_before_action :authenticate, only: %i[new complete]

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
      return redirect_to sign_in_path, notice: "If you just completed a payment, please check your email for a sign-in link."
    end

    begin
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)
      unless checkout_session.payment_status == 'paid'
        return redirect_to sign_up_path, alert: "Payment not completed."
      end

      customer_id = checkout_session.customer
      email = checkout_session.customer_details&.email
      subscription_id = checkout_session.subscription

      user = User.find_or_initialize_by(stripe_customer_id: customer_id)
      user.email = email
      user.stripe_subscription_id = subscription_id
      user.subscription_status = 'active'
      user.verified = true
      user.save!

      render inertia: "registrations/Complete", props: { email: email }
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error in complete: #{e.message}")
      redirect_to sign_up_path, alert: "Unable to verify payment."
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("User save failed in complete: #{e.message}")
      redirect_to sign_up_path, alert: "Unable to create your account. Please contact support."
    end
  end

  def destroy
    unless params[:confirmation].to_s == "DELETE"
      redirect_to settings_path,
                  alert: "Please type DELETE to confirm account deletion.",
                  status: :see_other
      return
    end

    user = current_user

    unless cancel_stripe_subscription_for(user)
      redirect_to settings_path,
                  alert: "We could not cancel your subscription. Please try again.",
                  status: :see_other
      return
    end

    user.destroy!
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

    def cancel_stripe_subscription_for(user)
      if user.stripe_subscription_id.present?
        Rails.logger.info("Account deletion: canceling Stripe subscription by id for user_id=#{user.id} subscription_id=#{user.stripe_subscription_id}")
        result = Stripe::Subscription.cancel(user.stripe_subscription_id)
        Rails.logger.info("Account deletion: Stripe cancel result status=#{result.status} for user_id=#{user.id}")
        return true
      end

      if user.stripe_customer_id.blank?
        Rails.logger.info("Account deletion: no Stripe subscription/customer for user_id=#{user.id}, skipping Stripe cancellation")
        return true
      end

      Rails.logger.info("Account deletion: no stored subscription id for user_id=#{user.id}, searching active Stripe subscriptions for customer_id=#{user.stripe_customer_id}")
      subscriptions = Stripe::Subscription.list(customer: user.stripe_customer_id, status: "all", limit: 10)
      cancellable_subscription = subscriptions.data.find { |sub| !%w[canceled incomplete_expired].include?(sub.status) }

      if cancellable_subscription.blank?
        Rails.logger.info("Account deletion: no cancellable Stripe subscriptions found for user_id=#{user.id} customer_id=#{user.stripe_customer_id}")
        return true
      end

      Rails.logger.info("Account deletion: canceling Stripe subscription found by customer for user_id=#{user.id} subscription_id=#{cancellable_subscription.id}")
      result = Stripe::Subscription.cancel(cancellable_subscription.id)
      Rails.logger.info("Account deletion: Stripe cancel result status=#{result.status} for user_id=#{user.id}")
      true
    rescue Stripe::InvalidRequestError => e
      message = e.message.to_s.downcase
      # Treat already-canceled / missing subscriptions as a success — the subscription
      # is in a terminal state and the account deletion should proceed.
      if message.include?("no such subscription") ||
         message.include?("resource_missing") ||
         message.include?("already been canceled") ||
         message.include?("already canceled")
        Rails.logger.warn("Account deletion: Stripe subscription already gone/canceled for user_id=#{user.id} subscription_id=#{user.stripe_subscription_id} (#{e.message})")
        return true
      end

      Rails.logger.error("Account deletion: Stripe invalid request for user_id=#{user.id} subscription_id=#{user.stripe_subscription_id} error=#{e.message}")
      false
    rescue Stripe::StripeError => e
      Rails.logger.error("Account deletion: Stripe error for user_id=#{user.id} subscription_id=#{user.stripe_subscription_id} error=#{e.message}")
      false
    end

end
