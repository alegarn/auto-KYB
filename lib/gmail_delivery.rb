require "net/http"
require "json"
require "base64"
require "digest"

class GmailDelivery

  class ApiAuthError < StandardError; end
  class InvalidRefreshTokenError < StandardError; end

  TOKEN_URL = "https://oauth2.googleapis.com/token"
  SEND_MESSAGE_URL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"
  OAUTH_CALLBACK_PATH = "/auth/google_oauth2/callback"
  DELIVERY_NAMESPACE = :gmail_delivery
  LEGACY_NAMESPACE = :google
  LOCALHOST_HOSTS = %w[localhost 127.0.0.1].freeze
  ENV_KEY_MAP = {
    gmail_delivery: {
      client_id: "GMAIL_CLIENT_ID",
      client_secret: "GMAIL_CLIENT_SECRET",
      refresh_token: "GMAIL_REFRESH_TOKEN"
    },
    google: {
      client_id: "GOOGLE_CLIENT_ID",
      client_secret: "GOOGLE_CLIENT_SECRET",
      refresh_token: "GOOGLE_REFRESH_TOKEN"
    }
  }.freeze
  INVALID_GRANT_MESSAGE = "GmailDelivery: Refresh token is invalid, expired, or revoked. Generate a new gmail_delivery.refresh_token and ensure the Google OAuth app is in Production/Internal.".freeze

  attr_accessor :settings

  def initialize(settings = {})
    @settings = settings
  end

  def self.delivery_credentials(credentials: Rails.application.credentials, env: ENV)
    dedicated = credential_set(DELIVERY_NAMESPACE, credentials: credentials, env: env)
    return dedicated if dedicated.values.any?(&:present?)

    credential_set(LEGACY_NAMESPACE, credentials: credentials, env: env)
  end

  def self.missing_credential_keys(credentials_hash = delivery_credentials)
    credentials_hash.filter_map do |key, value|
      key if value.blank?
    end
  end

  def self.oauth_redirect_uri(credentials: Rails.application.credentials, env: ENV, rails_env: Rails.env)
    explicit_redirect_uri = env["GMAIL_OAUTH_REDIRECT_URI"].presence ||
      credentials.dig(DELIVERY_NAMESPACE, :redirect_uri).presence
    return validate_redirect_uri(explicit_redirect_uri) if explicit_redirect_uri.present?

    base_url = env["APP_BASE_URL"].presence || credentials.dig(:app, :base_url).presence
    return validate_redirect_uri("#{base_url.to_s.sub(%r{/$}, "")}#{OAUTH_CALLBACK_PATH}") if base_url.present?

    return "http://localhost:3100#{OAUTH_CALLBACK_PATH}" if rails_env.development? || rails_env.test?

    raise ArgumentError, "GmailDelivery: Missing redirect URI configuration. Set gmail_delivery.redirect_uri, GMAIL_OAUTH_REDIRECT_URI, app.base_url, or APP_BASE_URL."
  end

  def self.credential_set(namespace, credentials: Rails.application.credentials, env: ENV)
    ENV_KEY_MAP.fetch(namespace).each_with_object({}) do |(key, env_key), set|
      set[key] = env[env_key].presence || credentials.dig(namespace, key).presence
    end
  end

  def self.validate_redirect_uri(uri_string)
    uri = URI.parse(uri_string)

    unless uri.is_a?(URI::HTTP) && uri.host.present?
      raise ArgumentError, "GmailDelivery: Invalid redirect URI configuration."
    end

    return uri_string if LOCALHOST_HOSTS.include?(uri.host)

    raise ArgumentError, "GmailDelivery: Redirect URI must use HTTPS outside localhost." unless uri.scheme == "https"

    uri_string
  rescue URI::InvalidURIError
    raise ArgumentError, "GmailDelivery: Invalid redirect URI configuration."
  end

  def deliver!(mail)
    ensure_credentials!

    # Mail should be base64url encoded
    message_base64 = Base64.urlsafe_encode64(mail.encoded, padding: false)

    deliver_message(message_base64)

    # ActionMailer expects the mail object to be returned
    mail
  end

  def verify!
    ensure_credentials!
    fetch_access_token(credentials, force_refresh: true)
    true
  end

  private

  def credentials
    @credentials ||= self.class.delivery_credentials
  end

  def ensure_credentials!
    return if self.class.missing_credential_keys(credentials).empty?

    Rails.logger.error "GmailDelivery: Missing Gmail delivery credentials (client_id, client_secret, refresh_token)"
    raise "GmailDelivery: Missing or incomplete Gmail delivery credentials"
  end

  def fetch_access_token(credentials, force_refresh: false)
    return exchange_access_token(credentials) if force_refresh

    # Cache the short-lived access token for 50 minutes (Google tokens expire in 60 mins)
    Rails.cache.fetch(access_token_cache_key(credentials), expires_in: 50.minutes) do
      exchange_access_token(credentials)
    end
  end

  def access_token_cache_key(credentials)
    refresh_token_digest = Digest::SHA256.hexdigest(credentials.fetch(:refresh_token))

    [ "gmail_api_access_token", credentials.fetch(:client_id), refresh_token_digest ].join("/")
  end

  def deliver_message(message_base64)
    access_token = fetch_access_token(credentials)
    send_via_gmail_api(access_token, message_base64)
  rescue ApiAuthError
    Rails.cache.delete(access_token_cache_key(credentials))

    fresh_access_token = fetch_access_token(credentials, force_refresh: true)
    send_via_gmail_api(fresh_access_token, message_base64)
  end

  def token_exchange_error(result)
    return InvalidRefreshTokenError.new(INVALID_GRANT_MESSAGE) if result["error"] == "invalid_grant"

    RuntimeError.new("GmailDelivery: Failed to get access token (#{result['error']})")
  end

  def exchange_access_token(credentials)
    uri = URI(TOKEN_URL)

    response = Net::HTTP.post_form(uri, {
      client_id: credentials[:client_id],
      client_secret: credentials[:client_secret],
      refresh_token: credentials[:refresh_token],
      grant_type: "refresh_token"
    })

    result = parse_response_body(response)

    if result["error"].present?
      Rails.logger.error "GmailDelivery: Failed to get access token - #{result['error']}: #{result['error_description']}"
      raise token_exchange_error(result)
    end

    result["access_token"]
  end

  def send_via_gmail_api(access_token, message_base64)
    uri = URI(SEND_MESSAGE_URL)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    })

    request.body = { raw: message_base64 }.to_json

    response = http.request(request)
    result = parse_response_body(response)

    if response.code.to_i >= 400
      error_message = parsed_api_error_message(result, response)
      Rails.logger.error "GmailDelivery: API Error - #{error_message}"
      raise ApiAuthError, error_message if [ 401, 403 ].include?(response.code.to_i)

      raise "GmailDelivery: API Error (#{response.code}) - #{error_message}"
    end

    result
  end

  def parse_response_body(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    { "error" => "http_#{response.code}", "error_description" => response.body.to_s }
  end

  def parsed_api_error_message(result, response)
    error_payload = result["error"]
    return error_payload["message"] if error_payload.is_a?(Hash) && error_payload["message"].present?

    result["error_description"].presence || response.body
  end

end
