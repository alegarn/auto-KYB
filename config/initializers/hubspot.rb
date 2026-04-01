# frozen_string_literal: true

module HubspotConfig
  def self.client_id
    Rails.application.credentials.dig(:hubspot, :client_id) || ENV["HUBSPOT_CLIENT_ID"]
  end

  def self.client_secret
    Rails.application.credentials.dig(:hubspot, :client_secret) || ENV["HUBSPOT_CLIENT_SECRET"]
  end

  def self.redirect_uri
    Rails.application.credentials.dig(:hubspot, :redirect_uri) ||
      ENV["HUBSPOT_REDIRECT_URI"] ||
      "#{base_url}/crm_connections/hubspot/callback"
  end

  def self.scopes
    Rails.application.credentials.dig(:hubspot, :scopes) ||
      ENV["HUBSPOT_SCOPES"] ||
      "oauth crm.objects.contacts.read crm.objects.contacts.write crm.objects.companies.read crm.objects.companies.write"
  end

  def self.authorize_url
    Rails.application.credentials.dig(:hubspot, :authorize_url) ||
      ENV["HUBSPOT_AUTHORIZE_URL"] ||
      "https://app.hubspot.com/oauth/authorize"
  end

  def self.configured?
    client_id.present? && client_secret.present? && redirect_uri.present?
  end

  def self.base_url
    Rails.application.credentials.dig(:app, :base_url) || ENV.fetch("APP_BASE_URL", "http://localhost:3100")
  end
end

if Rails.env.production? && !HubspotConfig.configured?
  Rails.logger.fatal("[HubSpot] Missing hubspot.client_id, hubspot.client_secret, or hubspot.redirect_uri in credentials")
  raise "Missing HubSpot configuration in production"
end
