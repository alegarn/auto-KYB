class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :set_current_request_details
  before_action :authenticate

  private
    def authenticate
      token = cookies.signed[:session_token] || cookies[:session_token] || request.cookies['session_token']
      puts "[TEST LOG] ApplicationController#authenticate called; token=#{token.inspect}" if Rails.env.test?
      if session_record = Session.find_by_id(token)
        Current.session = session_record
      else
        redirect_to sign_in_path
      end
    end

    def set_current_request_details
      # Prefer request headers but fall back to common test env keys so controller specs work
      Current.user_agent = request.env['HTTP_USER_AGENT'] || request.headers['User-Agent'] || request.user_agent
      Current.ip_address = request.env['REMOTE_ADDR'] || request.remote_ip || request.ip
    end
end
