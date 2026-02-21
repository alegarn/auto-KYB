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
      redirect_to sign_in_path, notice: "Welcome! Check your email to verify your account"
    else
      flash.now.inertia[:alert] = 'There was an error with your registration'
      render inertia: 'registrations/new', props: { user: @user }, status: :unprocessable_entity
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
