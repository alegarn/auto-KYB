class Sessions::PasswordlessesController < ApplicationController

  skip_before_action :authenticate
  before_action :skip_authorization

  before_action :set_user, only: :edit

  def edit
    unless @user.eligible_for_sign_in?
      redirect_to sign_in_path, alert: "Your account is no longer active."
      return
    end

    session_record = @user.sessions.create!
    cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

    destination = auth_navigation_for(@user).post_login_path
    redirect_to(destination, notice: "Signed in successfully", status: :see_other)
  end

  private
    def set_user
      @user = User.find_by_token_for!(:signin, params[:sid])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to sign_in_path, alert: "That sign in link is invalid or expired"
    end

end
