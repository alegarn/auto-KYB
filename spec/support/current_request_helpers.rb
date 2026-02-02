# Populate Current and Current.session for controller specs from the test request
module ControllerRequestHelpers
  [ :get, :post, :put, :patch, :delete ].each do |http_method|
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

      Current.session = Session.find_by(id: token) if token

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
