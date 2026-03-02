# frozen_string_literal: true

module Crm
  module Hubspot
    class ContactMapper

      # Maps a Quick KYB Client to HubSpot Contact properties
      #
      # @param client [Client] the client record
      # @param data [Hash] additional form response data (optional overrides)
      def initialize(client, data = {})
        @client = client
        @data = data.with_indifferent_access
      end

      def to_hubspot_properties
        props = {}

        # Standard HubSpot Contact properties
        props[:email]     = @client.email                        if @client.email.present?
        props[:phone]     = @client.phone                        if @client.phone.present?
        props[:company]   = @client.company_name                 if @client.company_name.present?
        props[:address]   = @client.address                      if @client.address.present?

        # Split name into first/last (HubSpot expects separate fields)
        if @client.name.present?
          parts = @client.name.split(" ", 2)
          props[:firstname] = parts[0]
          props[:lastname]  = parts[1] || ""
        end

        # Merge any extra data from form responses
        props.merge!(extract_custom_properties)

        props.compact
      end

      private

      def extract_custom_properties
        custom = {}
        # Map known form-response keys to HubSpot custom properties
        # (These replace the need for Custom Objects for KYC Profile data)
        custom[:country] = @data[:country] if @data[:country].present?
        custom[:kyb_verification_status] = @data[:kyb_status] || @data[:kyc_status] if @data[:kyb_status].present? || @data[:kyc_status].present?
        custom[:kyb_risk_score] = @data[:risk_score] if @data[:risk_score].present?

        # Include any remaining form fields as custom properties
        known_keys = %w[country kyb_status kyc_status risk_score]
        @data.each do |k, v|
          next if known_keys.include?(k.to_s)
          custom[k.to_sym] = v if v.present?
        end

        custom
      end

    end
  end
end
