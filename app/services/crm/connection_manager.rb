module Crm
  class ConnectionManager
    def self.service_for(connection)
      case connection.provider
      when 'hubspot'
        HubspotService.new(connection)
      when 'salesforce'
        SalesforceService.new(connection)
      when 'zoho'
        ZohoService.new(connection)
      else
        raise ArgumentError, "Unknown CRM provider: #{connection.provider}"
      end
    end

    def self.active_connections_for(user)
      user.crm_connections.where(status: 'active')
    end
  end
end