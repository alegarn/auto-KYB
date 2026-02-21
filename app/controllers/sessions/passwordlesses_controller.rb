class Sessions::PasswordlessesController < ApplicationController
  skip_before_action :authenticate

  before_action :set_user, only: :edit

  def edit
    session_record = @user.sessions.create!
    cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

    redirect_to(auth_loading_path, notice: "Signed in successfully", status: :see_other)
  end

  private
    def set_user
      @user = User.find_by_token_for!(:signin, params[:sid])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to sign_in_path, alert: "That sign in link is invalid or expired"
    end
end
