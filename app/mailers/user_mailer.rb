class UserMailer < ApplicationMailer

  def passwordless
    @user = params[:user]
    @signed_id = @user.generate_token_for(:signin)

    mail to: @user.email, subject: "Your sign-in link"
  end

  def welcome
    @user = params[:user]
    @signin_token = @user.generate_token_for(:signin)

    mail to: @user.email, subject: "Welcome to Quick KYB — here's your sign-in link"
  end

  def email_verification
    @user = params[:user]
    @signed_id = @user.generate_token_for(:email_verification)

    mail to: @user.email, subject: "Verify your email"
  end

  def subscription_payment_failed
    @user = params[:user]
    mail to: @user.email, subject: "Action required: payment failed for your Quick KYB subscription"
  end

  def subscription_payment_recovered
    @user = params[:user]
    mail to: @user.email, subject: "Payment confirmed — your Quick KYB subscription is active"
  end

end
