class CrmSyncService

  def self.call(client, strategy, external_contact_id: nil, external_company_id: nil, sync_address_to_contact: false)
    return unless strategy
    return if strategy == "skip"

    connection = connection_for(client, strategy)
    return unless connection

    case strategy
    when "link"
      if external_contact_id.present? || external_company_id.present?
        CrmClientLink.find_or_create_by!(
          client: client,
          crm_connection: connection
        ) do |link|
          link.external_contact_id = external_contact_id if external_contact_id.present?
          link.external_company_id = external_company_id if external_company_id.present?
        end
      end
    when "create"
      service = Crm::ConnectionManager.service_for(connection)

      # 1. Create contact
      contact_result = service.create_contact(client, sync_address_to_contact: sync_address_to_contact)

      new_external_company_id = external_company_id

      # 2. Manage Company
      if new_external_company_id.blank? && client.company_name.present?
        # Check if service supports searching companies (graceful degradation)
        if service.respond_to?(:search_companies)
          # Try to find exactly matching company first
          found_companies = service.search_companies(client.company_name)
          if found_companies.any?
            # exact match by name ignoring case
            exact_match = found_companies.find { |c| c[:company_name].to_s.casecmp?(client.company_name) }
            new_external_company_id = exact_match[:hubspot_id] if exact_match
          end
        end

        # If still blank, create the company
        if new_external_company_id.blank? && service.respond_to?(:create_company)
          company_result = service.create_company(client, {})
          new_external_company_id = company_result[:id] if company_result
        end
      end

      # 3. Associate if both exist
      if contact_result[:id].present? && new_external_company_id.present? && service.respond_to?(:associate_contact_to_company)
        service.associate_contact_to_company(contact_result[:id], new_external_company_id)
      end

      if contact_result[:id] || new_external_company_id
        link = CrmClientLink.find_or_initialize_by(client: client, crm_connection: connection)
        link.external_contact_id = contact_result[:id] if contact_result[:id].present?
        link.external_company_id = new_external_company_id if new_external_company_id.present?
        link.save!
      end
    when "update"
      service = Crm::ConnectionManager.service_for(connection)
      result = service.export_data(
        client,
        { sync_address_to_contact: sync_address_to_contact },
        [],
        company_data: profile_company_data(client)
      )
      persist_link_from_export!(client, connection, result)
    end
  rescue => e
    Rails.logger.fatal("CrmSyncService Error: #{e.message}\n#{e.backtrace.join(%Q(\n))}")
    Rails.logger.error("CrmSyncService Error: #{e.message}")
  end

  def self.connection_for(client, strategy)
    linked_connection = client.crm_client_link&.crm_connection
    return linked_connection if strategy == "update" && linked_connection&.status == "active"

    client.user.crm_connections.active.first
  end

  def self.profile_company_data(client)
    data = {}
    data[:company_id] = client.company_id if client.company_id.present?
    data
  end

  def self.persist_link_from_export!(client, connection, result)
    return unless result.is_a?(Hash) && result[:success]

    external_contact_id = result[:external_id].presence || result.dig(:details, :contact, :id).presence
    external_company_id = result.dig(:details, :company, :id).presence
    return if external_contact_id.blank? && external_company_id.blank?

    link = CrmClientLink.find_or_initialize_by(client: client, crm_connection: connection)
    link.external_contact_id = external_contact_id if external_contact_id.present?
    link.external_company_id = external_company_id if external_company_id.present?
    link.save!
  end

  private_class_method :connection_for, :profile_company_data, :persist_link_from_export!

end
