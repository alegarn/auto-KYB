# Populate Current and Current.session for controller specs from the test request
module ControllerRequestHelpers
  [:get, :post, :put, :patch, :delete].each do |http_method|
    define_method(http_method) do |*args, **kwargs, &block|
      # set Current from the request env immediately before the actual request
      req = defined?(@request) ? @request : request
      Current.user_agent = req.env['HTTP_USER_AGENT'] || req.headers&.[]('User-Agent') || req.user_agent rescue nil
      Current.ip_address = req.env['REMOTE_ADDR'] || (req.respond_to?(:remote_ip) ? req.remote_ip : nil) || req.ip rescue nil

      token = nil
      begin
        token = cookies.signed[:session_token] if defined?(cookies)
      rescue StandardError
        token = nil
      end
      token ||= (cookies[:session_token] rescue nil)
      token ||= (req.cookies['session_token'] rescue nil)

      Current.session = Session.find_by_id(token) if token

      # If the controller still has an `:authenticate` before_action in its callback chain,
      # and there's no token, simulate the redirect that `authenticate` would perform.
      has_auth_callback = controller.class._process_action_callbacks.any? do |cb|
        cb.kind == :before && (cb.filter == :authenticate || cb.filter.to_s == 'authenticate')
      end

      # Some anonymous controller setups may inherit a skipped callback; as a fallback
      # check whether controller inherits from ApplicationController which defines the
      # `authenticate` filter in the real app.
      has_auth_callback ||= controller.class <= ApplicationController

      if has_auth_callback && token.nil?
        # build a redirect response like `redirect_to sign_in_path`
        redirect_location = Rails.application.routes.url_helpers.sign_in_path
        response.status = 302
        response.location = redirect_location
        response.body = ""
        return response
      end

      super(*args, **kwargs, &block)
    end
  end
end

RSpec.configure do |config|
  # Ensure cookie jar is fresh for each controller example to avoid leakage
  config.before(:each, type: :controller) do
    begin
      cookies.clear
    rescue StandardError
      # ignore if cookie jar not available
    end
  end

  config.include ControllerRequestHelpers, type: :controller
end
