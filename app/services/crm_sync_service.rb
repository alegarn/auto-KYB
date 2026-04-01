class CrmSyncService

  UNAUTHORIZED = :unauthorized

  def self.call(client, strategy, external_contact_id: nil, external_company_id: nil, sync_address_to_contact: false, source: nil, scheduler: Crm::TransferScheduler)
    return unless strategy
    return if strategy == "skip"
    return UNAUTHORIZED unless Crm::Entitlement.new(client.user).allowed?

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
      # Schedule an async CRM transfer instead of calling provider inline
      request_context = {
        source: source,
        sync_address_to_contact: ActiveRecord::Type::Boolean.new.cast(sync_address_to_contact),
        external_company_id: external_company_id.presence
      }.compact

      scheduler.new(
        client: client,
        connection: connection,
        trigger: CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC,
        request_context: request_context
      ).schedule_export!
    when "update"
      scheduler.new(
        client: client,
        connection: connection,
        trigger: CrmTransfer::TRIGGER_CLIENT_EDIT_SYNC,
        request_context: {
          source: source,
          sync_address_to_contact: ActiveRecord::Type::Boolean.new.cast(sync_address_to_contact)
        }.compact
      ).schedule_export!
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
