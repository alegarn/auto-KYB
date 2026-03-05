# frozen_string_literal: true

module Crm
  module Hubspot
    class DataFetcher

      CONTACT_PROPERTIES = %w[email firstname lastname phone company address city zip state country].freeze
      COMPANY_PROPERTIES = %w[name phone address city zip state domain country registration_number].freeze

      def initialize(client)
        @client = client
      end

      # Fetch a page of contacts
      # @return [Hash] { results: [...], paging: { next: { after: "..." } } }
      def fetch_contacts(limit: 100, after: nil)
        params = {
          limit: limit,
          properties: CONTACT_PROPERTIES
        }
        params[:after] = after if after

        response = @client.contacts_api.get_page(**params)
        {
          results: response.results.map { |r| map_contact(r) },
          paging: extract_paging(response)
        }
      end

      # Fetch a page of companies
      def fetch_companies(limit: 100, after: nil)
        params = {
          limit: limit,
          properties: COMPANY_PROPERTIES
        }
        params[:after] = after if after

        response = @client.companies_api.get_page(**params)
        {
          results: response.results.map { |r| map_company(r) },
          paging: extract_paging(response)
        }
      end

      # Search contacts by email
      def search_contact_by_email(email)
        body = {
          filterGroups: [ {
            filters: [ {
              propertyName: "email",
              operator: "EQ",
              value: email
            } ]
          } ],
          properties: CONTACT_PROPERTIES,
          limit: 1
        }
        response = @client.contacts_search_api.do_search(body: body)
        response.results.first ? map_contact(response.results.first) : nil
      end

      # Search contacts by generic query
      def search_contacts(query)
        body = {
          query: query,
          properties: CONTACT_PROPERTIES,
          limit: 10
        }
        response = @client.contacts_search_api.do_search(body: body)
        response.results.map { |r| map_contact(r) }
      end

      # Fetch a single contact by ID
      def fetch_contact(external_id)
        response = @client.contacts_api.get_by_id(contact_id: external_id, properties: CONTACT_PROPERTIES)
        map_contact(response)
      rescue ::Hubspot::ApiError => e
        Rails.logger.error("[HubSpot Fetch Contact] #{e.message}")
        nil
      end

      private

      def map_contact(hubspot_contact)
        props = hubspot_contact.properties
        {
          external_contact_id: hubspot_contact.id,
          email:        props["email"],
          first_name:   props["firstname"],
          last_name:    props["lastname"],
          name:         [ props["firstname"], props["lastname"] ].compact.join(" "),
          phone:        props["phone"],
          company_name: props["company"],
          address: {
            street:      props["address"],
            city:        props["city"],
            postal_code: props["zip"],
            state:       props["state"]
          },
          country:      props["country"]
        }
      end

      def map_company(hubspot_company)
        props = hubspot_company.properties
        {
          hubspot_id:   hubspot_company.id,
          company_name: props["name"],
          phone:        props["phone"],
          address: {
            street:      props["address"],
            city:        props["city"],
            postal_code: props["zip"],
            state:       props["state"]
          },
          domain:       props["domain"],
          country:      props["country"],
          company_id:   props["registration_number"]
        }
      end

      def extract_paging(response)
        if response.paging&.next_page
          { next: { after: response.paging.next_page.after } }
        else
          nil
        end
      end

    end
  end
end
