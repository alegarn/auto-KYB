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
    def export_data(client, data, files = [], company_data: {})
      ensure_valid_token!

      link = client.respond_to?(:crm_client_link) ? client.crm_client_link : nil

      results = {}

      # 1. Update existing contact (or create if not linked)
      external_id = link&.external_contact_id
      if external_id.blank?
        created = create_contact(client)
        external_id = created[:id]
        contact_result = { id: external_id, action: :created }
      else
        contact_result = update_existing_contact(client, external_id, data)
      end
      results[:contact] = contact_result

      # 2. Create/update company if company_data or company_name is present
      if company_data.present? || client.company_name.present?
        company_id = link&.respond_to?(:external_company_id) ? link&.external_company_id : nil

        if company_id.blank?
          # Try to find existing company by name before creating a duplicate
          company_id = search_company(client) if client.company_name.present?
        end

        if company_id.present?
          company_result = update_existing_company(company_id, company_data)
        else
          company_result = create_company(client, company_data)
          company_id = company_result[:id]
        end
        results[:company] = company_result

        # 3. Associate contact <-> company
        if external_id.present? && company_id.present?
          associate_contact_to_company(external_id, company_id)
          results[:association] = { contact_id: external_id, company_id: company_id, action: :linked }
        end
      end

      # 4. Upload files (if any)
      if files.any?
        file_results = upload_files(files, contact_id: external_id, company_id: company_id)
        results[:files] = file_results
      end

      { success: true, external_id: external_id, details: results }
    rescue StandardError => e
      Rails.logger.error("[HubSpot Export] #{e.class}: #{e.message}")
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

    # Search companies by query
    def search_companies(query)
      ensure_valid_token!
      Crm::Hubspot::DataFetcher.new(hubspot_client).search_companies(query)
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

    def create_contact(client, sync_address_to_contact: false)
      mapper = Crm::Hubspot::ContactMapper.new(client, { sync_address_to_contact: sync_address_to_contact })
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
        raise "Error creating contact (HTTP #{res.code}): #{res.body}"
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
        raise "Error updating contact (HTTP #{res.code}): #{res.body}"
      end
    end

    def create_company(client, company_data = {})
      mapper = Crm::Hubspot::CompanyMapper.new(client, company_data)
      properties = mapper.to_hubspot_properties
      ensure_properties("companies", properties)

      body = { properties: properties.transform_keys { |k| k.to_s.downcase.gsub(/[^a-z0-9]/, "_") }.transform_values(&:to_s) }

      res = hubspot_client.api_request(
        method: "POST",
        path: "/crm/v3/objects/companies",
        body: body
      )

      if res.code.to_i < 300
        parsed = JSON.parse(res.body)
        { id: parsed["id"], action: :created }
      else
        raise "Error creating company (HTTP #{res.code}): #{res.body}"
      end
    end

    def update_existing_company(company_id, company_data)
      properties = company_data.transform_keys { |k| k.to_s.downcase.gsub(/[^a-z0-9]/, "_") }.transform_values(&:to_s)
      ensure_properties("companies", properties)

      res = hubspot_client.api_request(
        method: "PATCH",
        path: "/crm/v3/objects/companies/#{company_id}",
        body: { properties: properties }
      )

      if res.code.to_i < 300
        { id: company_id, action: :updated }
      else
        raise "Error updating company (HTTP #{res.code}): #{res.body}"
      end
    end


    def ensure_properties(object_type, properties_hash)
      return if properties_hash.empty?

      res = hubspot_client.api_request(method: "GET", path: "/properties/v1/#{object_type}/properties")
      return unless res.code.to_i == 200

      all_props = JSON.parse(res.body)
      all_props = [] unless all_props.is_a?(Array)

      existing = all_props.map { |p| p["name"] }
      read_only_props = all_props.select { |p| p["readOnlyValue"] || p["calculated"] }.map { |p| p["name"] }

      properties_hash.keys.each do |k|
        prop_name = k.to_s.downcase.gsub(/[^a-z0-9]/, "_")

        if read_only_props.include?(prop_name)
          properties_hash.delete(k)
          next
        end

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

    def upload_files(files, contact_id: nil, company_id: nil)
      uploader = Crm::Hubspot::FileUploader.new(hubspot_client)
      files.filter_map do |item|
        # support both old array of UploadedFile and new array of Hashes [{file: UploadedFile, target: :contact, action: '__note_attachment__'}]
        uploaded_file = item.is_a?(Hash) ? item[:file] : item
        target = item.is_a?(Hash) ? item[:target] : :contact
        action = item.is_a?(Hash) ? item[:action] : "__note_attachment__"

        next unless uploaded_file.file.attached?

        # Currently HubSpot implementation only supports note attachment
        next unless action == "__note_attachment__"

        target_id = target == :company ? company_id : contact_id
        next if target_id.blank?

        uploader.upload(uploaded_file, target_type: target, target_id: target_id)
      end
    end

  end
end
