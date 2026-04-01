Rails.application.config.middleware.use OmniAuth::Builder do
  google_client_id     = Rails.application.credentials.dig(:google, :client_id)     || ENV["GOOGLE_CLIENT_ID"]
  google_client_secret = Rails.application.credentials.dig(:google, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"]
  base_url             = Rails.application.credentials.dig(:app, :base_url)         || ENV.fetch("APP_BASE_URL", "http://localhost:3100")

  provider :google_oauth2, google_client_id, google_client_secret,
    {
      redirect_uri: "#{base_url}/auth/google_oauth2/callback"
    }
end
OmniAuth.config.allowed_request_methods = %i[post]
