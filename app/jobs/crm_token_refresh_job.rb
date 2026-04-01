# frozen_string_literal: true

class CrmTokenRefreshJob < ApplicationJob
  queue_as :default

  def perform
    CrmConnection.active.where(provider: "hubspot").find_each do |connection|
      next unless connection.token_expires_soon?(buffer: 10.minutes)

      begin
        service = Crm::ConnectionManager.service_for(connection)
        service.refresh_token!
        Rails.logger.info("[CRM] Proactively refreshed HubSpot token for user #{connection.user_id}")
      rescue => e
        Rails.logger.error("[CRM] Token refresh failed for connection #{connection.id}: #{e.message}")
      end
    end
  end
end
