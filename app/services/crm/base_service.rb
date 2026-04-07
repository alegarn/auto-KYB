module Crm
  class BaseService

    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    # Returns the OAuth authorization URL for the provider
    def authorize_url
      raise NotImplementedError, "#{self.class} must implement #authorize_url"
    end

    # Exchanges an authorization code for access/refresh tokens
    def exchange_token(code)
      raise NotImplementedError, "#{self.class} must implement #exchange_token"
    end

    # Refreshes the access token using the refresh token
    def refresh_token!
      raise NotImplementedError, "#{self.class} must implement #refresh_token!"
    end

    # Exports client data to the CRM
    # @param client [Client] The client record to export
    # @param data [Hash] The mapped data to export
    # @param files [Array<UploadedFile>] The files to upload
    # @param company_data [Hash] Separate hash of properties destined for the Company object
    # @return [Hash] Result of the export (e.g., { success: true, external_id: '123' })
    def export_data(client, data, files = [], company_data: {})
      raise NotImplementedError, "#{self.class} must implement #export_data"
    end

    # Tests the connection to the CRM
    # @return [Boolean] True if connection is valid
    def test_connection
      raise NotImplementedError, "#{self.class} must implement #test_connection"
    end

    # Fetches a contact by external ID
    # @param external_id [String] The CRM's external ID
    # @return [Hash] The mapped contact data
    def fetch_company(external_id)
      raise NotImplementedError, "#{self.class} must implement #fetch_company"
    end

    def fetch_contact(external_id)
      raise NotImplementedError, "#{self.class} must implement #fetch_contact"
    end

    protected

    def ensure_valid_token!
      if connection.expires_at && connection.expires_at < Time.current
        refresh_token!
      end
    end

  end
end
