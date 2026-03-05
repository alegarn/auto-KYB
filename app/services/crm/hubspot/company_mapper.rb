# frozen_string_literal: true

module Crm
  module Hubspot
    class CompanyMapper

      def initialize(client, data = {})
        @client = client
        @data = data.with_indifferent_access
      end

      def to_hubspot_properties
        # Companies have slightly different property names in HubSpot than Contacts
        # but for simplicity we reuse the FieldMapper logic and adjust if needed.
        props = Crm::Hubspot::FieldMapper.map_to_hubspot(@client, @data)
        
        # Adjust property name differences for companies if any (HubSpot Company properties use 'name' instead of 'firstname'/'lastname')
        props[:name] = @client.company_name if @client.company_name.present?
        
        # Custom properties (requires creating custom properties in HubSpot via Settings -> Properties)
        # We use custom properties instead of Custom Objects to keep the API surface simpler.
        props[:registration_number] = @data[:company_id] if @data[:company_id].present?
        props[:kyb_verification_status] = @data[:kyc_status] if @data[:kyc_status].present?

        # Include any remaining form fields as custom properties
        known_keys = %w[company_id kyc_status]
        @data.each do |k, v|
          next if known_keys.include?(k.to_s)
          next if Crm::Hubspot::FieldMapper::HUBSPOT_CONTACT_MAP.keys.include?(k.to_sym)
          props[k.to_sym] = v if v.present?
        end

        props.compact
      end

    end
  end
end
