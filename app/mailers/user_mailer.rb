class UserMailer < ApplicationMailer

  def passwordless
    @user = params[:user]
    @signed_id = @user.generate_token_for(:signin)

    mail to: @user.email, subject: "Your sign-in link"
  end

  def email_verification
    @user = params[:user]
    @signed_id = @user.generate_token_for(:email_verification)

    mail to: @user.email, subject: "Verify your email"
  end

end
