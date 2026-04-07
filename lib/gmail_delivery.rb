require 'net/http'
require 'json'
require 'base64'

class GmailDelivery

  attr_accessor :settings

  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    credentials = Rails.application.credentials.google

    if credentials.blank? || credentials[:client_id].blank? || credentials[:client_secret].blank? || credentials[:refresh_token].blank?
      Rails.logger.error "GmailDelivery: Missing Google credentials (client_id, client_secret, refresh_token)"
      raise "GmailDelivery: Missing or incomplete Google credentials"
    end

    access_token = fetch_access_token(credentials)

    # Mail should be base64url encoded
    message_base64 = Base64.urlsafe_encode64(mail.encoded, padding: false)

    response = send_via_gmail_api(access_token, message_base64)

    # ActionMailer expects the mail object to be returned
    mail
  end

  private

  def fetch_access_token(credentials)
    # Cache the short-lived access token for 50 minutes (Google tokens expire in 60 mins)
    Rails.cache.fetch("gmail_api_access_token", expires_in: 50.minutes) do
      uri = URI('https://oauth2.googleapis.com/token')

      response = Net::HTTP.post_form(uri, {
        client_id: credentials[:client_id],
        client_secret: credentials[:client_secret],
        refresh_token: credentials[:refresh_token],
        grant_type: 'refresh_token'
      })

      result = JSON.parse(response.body)

      if result['error']
        Rails.logger.error "GmailDelivery: Failed to get access token - #{result['error']}: #{result['error_description']}"
        raise "GmailDelivery: Failed to get access token (#{result['error']})"
      end

      result['access_token']
    end
  end

  def send_via_gmail_api(access_token, message_base64)
    uri = URI('https://gmail.googleapis.com/gmail/v1/users/me/messages/send')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    })

    request.body = { raw: message_base64 }.to_json

    response = http.request(request)
    result = JSON.parse(response.body)

    if response.code.to_i >= 400
      error_message = result.dig('error', 'message') || response.body
      Rails.logger.error "GmailDelivery: API Error - #{error_message}"
      raise "GmailDelivery: API Error (#{response.code}) - #{error_message}"
    end

    result
  end

end
