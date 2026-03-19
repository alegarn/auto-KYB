# frozen_string_literal: true

module Crm
  module Hubspot
    class FieldMapper
      HUBSPOT_CONTACT_MAP = {
        email: "email",
        phone: "phone",
        company_name: "company",
        # Address fields
        street: "address",
        city: "city",
        postal_code: "zip",
        state: "state",
        country: "country"
      }.freeze

      def self.map_from_hubspot(properties)
        {
          email: properties["email"],
          phone: properties["phone"],
          company_name: properties["company"],
          name: [properties["firstname"], properties["lastname"]].compact_join(" "),
          first_name: properties["firstname"],
          last_name: properties["lastname"],
          address: {
            street: properties["address"],
            city: properties["city"],
            postal_code: properties["zip"],
            state: properties["state"]
          },
          country: properties["country"]
        }
      end

      def self.map_to_hubspot(client, extra_data = {})
        props = {}
        
        # Merge client data with overrides from extra_data if available
        # This allows form submission data to override stored client data during export
        country = extra_data[:country] || client.country
        
        # sync_address_to_contact: If true (e.g. checkbox checked), 
        # we sync the address to the Contact object in HubSpot.
        # is_company: If true (e.g. from CompanyMapper),
        # we always sync the address to the Company object in HubSpot.
        sync_address = (extra_data[:sync_address_to_contact].to_s == "true") || (extra_data[:is_company] == true)
        
        # Basic fields
        props[:email] = client.email if client.email.present?
        props[:phone] = client.phone if client.phone.present?
        props[:company] = client.company_name if client.company_name.present?
        
        # Name splitting
        if client.name.present?
          parts = client.name.split(" ", 2)
          props[:firstname] = parts[0]
          props[:lastname] = parts[1] || ""
        end

        # Address fields (assuming client.address is a Hash)
        # Only sync if sync_address is true (differentiates company vs personal)
        if sync_address
          if client.address.is_a?(Hash)
            address_data = client.address.with_indifferent_access
            props[:address] = address_data[:street] if address_data[:street].present?
            props[:city] = address_data[:city] if address_data[:city].present?
            props[:zip] = address_data[:postal_code] if address_data[:postal_code].present?
            props[:state] = address_data[:state] if address_data[:state].present?
          elsif client.address.is_a?(String)
            props[:address] = client.address
          end

          props[:country] = country if country.present?
        end

        props.compact
      end
    end
  end
end
