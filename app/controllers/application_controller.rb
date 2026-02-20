class ApplicationController < ActionController::Base

  include Pagy::Backend
  rescue_from ActionController::InvalidAuthenticityToken, with: :inertia_page_expired_error

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :authenticate

  helper_method :current_user, :current_session_id, :user_props, :default_inertia_props

  inertia_share flash: -> { flash.to_hash },
               session_id: -> { current_session_id }

  def current_user
    Current.session&.user
  end

  def current_session_id
    Current.session&.id
  end

  def user_props
    return nil unless current_user

    { id: current_user.id, email: current_user.email }
  end

  def default_inertia_props
    {
      user: user_props
    }
  end

  def store_client_form_one_time_password(client_form, password, expires_in: 5.minutes)
    session[:client_form_one_time_passwords] ||= {}
    session[:client_form_one_time_passwords][client_form.id.to_s] = {
      password: password,
      expires_at: expires_in.from_now.iso8601
    }
  end

  private
    def authenticate
      # Allow tests that set Current.session directly to bypass cookie-based lookup
      return if Current.session&.user.present?

      token = cookies.signed[:session_token] || cookies[:session_token] || request.cookies["session_token"]
      Rails.logger.debug "[TEST LOG] ApplicationController#authenticate called; token=#{token.inspect}" if Rails.env.test?
      if session_record = Session.find_by(id: token)
        if session_record.user.present?
          Current.session = session_record
          return
        end
      end

      redirect_to(sign_in_path) and return
    end

    def set_current_request_details
      # Prefer request headers but fall back to common test env keys so controller specs work
      Current.user_agent = request.env["HTTP_USER_AGENT"] || request.headers["User-Agent"] || request.user_agent
      Current.ip_address = request.env["REMOTE_ADDR"] || request.remote_ip || request.ip
    end

    def inertia_page_expired_error
      redirect_back_or_to('/', allow_other_host: false,
        notice: "The page expired, please try again.")
    end

end
