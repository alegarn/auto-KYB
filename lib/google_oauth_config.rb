module GoogleOAuthConfig
  CALLBACK_PATH = "/auth/google_oauth2/callback".freeze
  LOCAL_BASE_URL = "http://localhost:3100".freeze

  module_function

  def redirect_uri(credentials: Rails.application.credentials, env: ENV, rails_env: Rails.env)
    "#{base_url(credentials: credentials, env: env, rails_env: rails_env).to_s.sub(%r{/$}, "")}#{CALLBACK_PATH}"
  end

  def base_url(credentials: Rails.application.credentials, env: ENV, rails_env: Rails.env)
    env["APP_BASE_URL"].presence ||
      (credentials.dig(:app, :base_url).presence if rails_env.production?) ||
      LOCAL_BASE_URL
  end
end
