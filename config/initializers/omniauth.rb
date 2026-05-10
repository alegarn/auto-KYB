require Rails.root.join("lib/google_oauth_config")

Rails.application.config.middleware.use OmniAuth::Builder do
  google_client_id     = Rails.application.credentials.dig(:google, :client_id)     || ENV["GOOGLE_CLIENT_ID"]
  google_client_secret = Rails.application.credentials.dig(:google, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"]

  provider :google_oauth2, google_client_id, google_client_secret,
    {
      redirect_uri: GoogleOauthConfig.redirect_uri
    }
end
OmniAuth.config.allowed_request_methods = %i[post]
