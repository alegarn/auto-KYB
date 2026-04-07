module Crm
  class SalesforceService < BaseService

    def authorize_url
      # Dummy implementation
      "https://login.salesforce.com/services/oauth2/authorize?client_id=dummy&redirect_uri=dummy&response_type=code"
    end

    def exchange_token(code)
      # Dummy implementation
      connection.update!(
        access_token: "dummy_access_token",
        refresh_token: "dummy_refresh_token",
        expires_at: 1.hour.from_now,
        status: "active"
      )
    end

    def refresh_token!
      # Dummy implementation
      connection.update!(
        access_token: "new_dummy_access_token",
        expires_at: 1.hour.from_now
      )
    end

    def export_data(client, data, files = [], company_data: {})
      ensure_valid_token!
      # Dummy implementation
      Rails.logger.info "Exporting data to Salesforce for client #{client.id}"
      { success: true, external_id: "sf_#{client.id}" }
    end

    def test_connection
      ensure_valid_token!
      # Dummy implementation
      true
    end

  end
end
