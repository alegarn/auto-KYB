# frozen_string_literal: true

module Crm
  module Hubspot
    class DataFetcher

      CONTACT_PROPERTIES = %w[email firstname lastname phone company address].freeze
      COMPANY_PROPERTIES = %w[name phone address domain country registration_number].freeze

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

      private

      def map_contact(hubspot_contact)
        props = hubspot_contact.properties
        {
          hubspot_id:   hubspot_contact.id,
          email:        props["email"],
          name:         [ props["firstname"], props["lastname"] ].compact.join(" "),
          phone:        props["phone"],
          company_name: props["company"],
          address:      props["address"]
        }
      end

      def map_company(hubspot_company)
        props = hubspot_company.properties
        {
          hubspot_id:   hubspot_company.id,
          company_name: props["name"],
          phone:        props["phone"],
          address:      props["address"],
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
