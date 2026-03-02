# frozen_string_literal: true

module HubspotConfig
  CLIENT_ID     = ENV["HUBSPOT_CLIENT_ID"]
  CLIENT_SECRET = ENV["HUBSPOT_CLIENT_SECRET"]
  REDIRECT_URI  = ENV.fetch("HUBSPOT_REDIRECT_URI", "#{ENV.fetch('APP_BASE_URL', 'http://localhost:3100')}/crm_connections/hubspot/callback")
  SCOPES        = ENV.fetch("HUBSPOT_SCOPES", "oauth crm.objects.contacts.read crm.objects.contacts.write crm.objects.companies.read crm.objects.companies.write")

  def self.configured?
    CLIENT_ID.present? && CLIENT_SECRET.present? && REDIRECT_URI.present?
  end
end

if Rails.env.production? && !HubspotConfig.configured?
  Rails.logger.fatal("[HubSpot] Missing HUBSPOT_CLIENT_ID, HUBSPOT_CLIENT_SECRET, or HUBSPOT_REDIRECT_URI")
  raise "Missing HubSpot configuration in production"
end
