# frozen_string_literal: true

module Crm
  class HubspotService < BaseService

    # OAuth: build authorization URL
    def authorize_url
      state = SecureRandom.hex(24)
      oauth.authorize_url(state: state)
    end

    # OAuth: exchange code for tokens and persist to connection
    def exchange_token(code)
      tokens = oauth.exchange_code(code)

      connection.update!(
        access_token:  tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        expires_at:    Time.current + tokens[:expires_in].to_i.seconds,
        status:        "active",
        scopes:        HubspotConfig::SCOPES
      )
    end

    # OAuth: refresh access token
    def refresh_token!
      tokens = oauth.refresh_token(connection.refresh_token)

      connection.update!(
        access_token:  tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        expires_at:    Time.current + tokens[:expires_in].to_i.seconds
      )
    end

    # Export client data to HubSpot (contacts + companies + files)
    def export_data(client, data, files = [])
      ensure_valid_token!

      link = client.crm_client_link
      unless link&.external_contact_id
        return { success: false, error: "Client not linked to CRM. Create or link a contact first." }
      end

      results = {}

      # 1. Update existing contact (do NOT create implicitly)
      contact_result = update_existing_contact(client, link.external_contact_id, data)
      results[:contact] = contact_result

      # 2. Upload files (if any)
      if files.any?
        file_results = upload_files(files, contact_id: link.external_contact_id)
        results[:files] = file_results
      end

      { success: true, external_id: link.external_contact_id, details: results }
    rescue ::Hubspot::ApiError => e
      Rails.logger.error("[HubSpot Export] #{e.message}")
      { success: false, error: e.message }
    end



    # Test that the connection works by fetching account info
    def test_connection
      ensure_valid_token!
      # Simple API call to verify token validity (HubSpot metadata endpoint is on v1)
      response = hubspot_client.api_request(
        method: "GET",
        path: "/oauth/v1/access-tokens/#{connection.access_token}"
      )
      JSON.parse(response.body).key?("token")
    rescue => e
      Rails.logger.error("[HubSpot Test] #{e.message}")
      false
    end

    # --- Import (HubSpot -> Quick KYB) ---

    # Fetch contacts from HubSpot and return mapped data
    def fetch_contacts(limit: 100, after: nil)
      ensure_valid_token!
      Crm::Hubspot::DataFetcher.new(hubspot_client).fetch_contacts(limit: limit, after: after)
    end

    # Fetch companies from HubSpot and return mapped data
    def fetch_companies(limit: 100, after: nil)
      ensure_valid_token!
      Crm::Hubspot::DataFetcher.new(hubspot_client).fetch_companies(limit: limit, after: after)
    end

    # Search contacts by query
    def search_contacts(query)
      ensure_valid_token!
      Crm::Hubspot::DataFetcher.new(hubspot_client).search_contacts(query)
    end

    # Search contacts by email
    def search_contact_by_email(email)
      ensure_valid_token!
      Crm::Hubspot::DataFetcher.new(hubspot_client).search_contact_by_email(email)
    end

    def fetch_contact(external_id)
      ensure_valid_token!
      Crm::Hubspot::DataFetcher.new(hubspot_client).fetch_contact(external_id)
    end

    # --- Import (HubSpot -> Quick KYB) ---

    def oauth
      @oauth ||= Crm::Hubspot::OAuth.new(connection: connection)
    end

    def hubspot_client
      @hubspot_client ||= Crm::Hubspot::Client.new(connection)
    end

    def create_contact(client)
      mapper = Crm::Hubspot::ContactMapper.new(client, {})
      properties = mapper.to_hubspot_properties
      ensure_properties("contacts", properties)
      formatted_props = properties.map { |k, v| { property: k.to_s.downcase.gsub(/[^a-z0-9]/, "_"), value: v.to_s } }

      res = hubspot_client.api_request(
        method: "POST",
        path: "/contacts/v1/contact",
        body: { properties: formatted_props }
      )

      if res.code.to_i < 300
        parsed = JSON.parse(res.body)
        { id: parsed["vid"] || parsed["id"], action: :created }
      else
        raise ::Hubspot::ApiError, "Error creating contact: #{res.body}"
      end
    end

    def update_existing_contact(client, external_id, data)
      mapper = Crm::Hubspot::ContactMapper.new(client, data)
      properties = mapper.to_hubspot_properties
      ensure_properties("contacts", properties)
      formatted_props = properties.map { |k, v| { property: k.to_s.downcase.gsub(/[^a-z0-9]/, "_"), value: v.to_s } }

      res = hubspot_client.api_request(
        method: "POST",
        path: "/contacts/v1/contact/vid/#{external_id}/profile",
        body: { properties: formatted_props }
      )

      if res.code.to_i == 200 || res.code.to_i == 204
        { id: external_id, action: :updated }
      else
        raise ::Hubspot::ApiError, "Error updating contact: #{res.body}"
      end
    end


    def ensure_properties(object_type, properties_hash)
      return if properties_hash.empty?

      res = hubspot_client.api_request(method: "GET", path: "/properties/v1/#{object_type}/properties")
      return unless res.code.to_i == 200

      existing = JSON.parse(res.body).map { |p| p["name"] }

      properties_hash.each do |k, v|
        prop_name = k.to_s.downcase.gsub(/[^a-z0-9]/, "_")
        next if existing.include?(prop_name)

        group = object_type == "contacts" ? "contactinformation" : "companyinformation"
        payload = {
          name: prop_name,
          label: k.to_s.titleize,
          groupName: group,
          type: "string",
          fieldType: "text"
        }
        create_res = hubspot_client.api_request(
          method: "POST",
          path: "/properties/v1/#{object_type}/properties",
          body: payload
        )

        if create_res.code.to_i >= 400
          Rails.logger.info("[HubSpot Property] Could not create #{prop_name}: #{create_res.body}")
        end
      end
    end

    def search_company(client)
      body = {
        filterGroups: [ {
          filters: [ {
            propertyName: "name",
            operator: "EQ",
            value: client.company_name
          } ]
        } ],
        limit: 1
      }
      response = hubspot_client.companies_search_api.do_search(body: body)
      response.results.first&.id
    end

    def search_contact(client)
      return nil if client.email.blank?

      body = {
        filterGroups: [ {
          filters: [ {
            propertyName: "email",
            operator: "EQ",
            value: client.email
          } ]
        } ],
        limit: 1
      }
      response = hubspot_client.contacts_search_api.do_search(body: body)
      response.results.first&.id
    end

    def associate_contact_to_company(contact_id, company_id)
      hubspot_client.api_request(
        method: "PUT",
        path: "/crm/v3/objects/contacts/#{contact_id}/associations/companies/#{company_id}/1"
      )
    rescue => e
      Rails.logger.warn("[HubSpot Association] #{e.message}")
    end

    def upload_files(files, contact_id: nil)
      uploader = Crm::Hubspot::FileUploader.new(hubspot_client)
      files.filter_map do |uploaded_file|
        next unless uploaded_file.file.attached?
        uploader.upload(uploaded_file, associate_to_contact: contact_id)
      end
    end

  end
end
