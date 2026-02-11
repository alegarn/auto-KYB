class RegistrationsController < ApplicationController

  skip_before_action :authenticate

  def new
    @user = User.new
    render inertia: "registrations/new", props: { user: @user }
  end

  def create
    @user = User.new(user_params)
    if @user.save
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

      #send_email_verification
      redirect_to dashboard_path, notice: "Welcome! You have signed up successfully"
    else
      flash.now.inertia[:alert] = 'There was an error with your registration'
      render inertia: 'registrations/new', props: { user: @user }, status: :unprocessable_entity
    end
  end

  private
    def user_params
      # Accept either top-level params or nested under :registration
      source = params[:registration] || params
      permitted = source.permit(:email, :password, :password_confirmation, :pwd)

      # If frontend sends `pwd` instead of `password`, map it through
      if permitted[:password].blank? && permitted[:pwd].present?
        { 'email' => permitted[:email], 'password' => permitted[:pwd], 'password_confirmation' => permitted[:password_confirmation] }
      else
        permitted.to_h
      end
    end

    def send_email_verification
      UserMailer.with(user: @user).email_verification.deliver_later
    end

end
