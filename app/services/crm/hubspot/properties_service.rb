# frozen_string_literal: true

module Crm
  module Hubspot
    class PropertiesService

      def initialize(user)
        @connection = Crm::ConnectionManager.active_connections_for(user).find { |c| c.provider == "hubspot" }
        @client = Crm::Hubspot::Client.new(@connection) if @connection
      end

      # List properties for a given object type ('contact' or 'company')
      def list_properties(object_type: "contact", force: false)
        return [] unless @client

        cache_key = "hubspot_properties_v2_#{object_type}_#{@connection.id}"
        cached = Rails.cache.read(cache_key)
        return cached if cached && !force

        begin
          response = @client.sdk.crm.properties.core_api.get_all(object_type: object_type)

          properties = response.results.map do |prop|
            {
              name: prop.name,
              label: prop.label,
              type: prop.type,
              field_type: prop.field_type,
              read_only: !!(prop.respond_to?(:calculated) && prop.calculated ||
                            prop.respond_to?(:modification_metadata) && prop.modification_metadata&.respond_to?(:read_only_value) && prop.modification_metadata.read_only_value ||
                            prop.respond_to?(:read_only_value) && prop.read_only_value),
              hubspot_defined: prop.respond_to?(:hubspot_defined) ? prop.hubspot_defined : false,
              hidden: prop.respond_to?(:hidden) ? prop.hidden : false,
              options: prop.options&.map { |o| { label: o.label, value: o.value } }
            }
          end

          filtered_properties = properties.reject { |p| p[:hidden] }
          Rails.cache.write(cache_key, filtered_properties, expires_in: 12.hours)
          filtered_properties
        rescue StandardError => e
          Rails.logger.error("[Hubspot::PropertiesService] Failed to list properties: #{e.message}")
          [] # Return empty to prevent UI crashing, but do NOT cache it.
        end
      end

    end
  end
end
