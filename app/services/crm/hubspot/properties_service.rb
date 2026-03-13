# frozen_string_literal: true

module Crm
  module Hubspot
    class PropertiesService
      def initialize(user)
        @connection = Crm::ConnectionManager.active_connections_for(user).find { |c| c.provider == 'hubspot' }
        @client = Crm::Hubspot::Client.new(@connection) if @connection
      end

      # List properties for a given object type ('contact' or 'company')
      def list_properties(object_type: 'contact')
        return [] unless @client

        Rails.cache.fetch("hubspot_properties_#{object_type}_#{@connection.id}", expires_in: 12.hours) do
          # Try to get them using the standard SDK
          begin
            response = @client.sdk.crm.properties.core_api.get_all(object_type: object_type)
            
            # Filter out read only and calculated properties
            filterable_results = response.results.reject do |prop|
              prop.calculated || prop.modification_metadata&.read_only_value
            end

            filterable_results.map do |prop|
              {
                name: prop.name,
                label: prop.label,
                type: prop.type,
                field_type: prop.field_type,
                options: prop.options&.map { |o| { label: o.label, value: o.value } }
              }
            end
          rescue StandardError => e
            Rails.logger.error("[Hubspot::PropertiesService] Failed to list properties: #{e.message}")
            []
          end
        end
      end
    end
  end
end
