class CrmSyncService

  def self.call(client, strategy, external_contact_id: nil)
    return unless strategy
    return if strategy == "skip"

    connection = client.user.crm_connections.active.first
    return unless connection

    case strategy
    when "link"
      if external_contact_id.present?
        CrmClientLink.find_or_create_by!(
          client: client,
          crm_connection: connection
        ) do |link|
          link.external_contact_id = external_contact_id
        end
      end
    when "create"
      service = Crm::ConnectionManager.service_for(connection)

      # We just want to ensure contact is created
      # And maybe company too.
      result = service.create_contact(client)

      if result[:id]
        CrmClientLink.find_or_create_by!(
          client: client,
          crm_connection: connection
        ) do |link|
          link.external_contact_id = result[:id]
        end
      end
    end
  rescue => e
    Rails.logger.fatal("CrmSyncService Error: #{e.message}
#{e.backtrace.join(%Q(
))}")
    Rails.logger.error("CrmSyncService Error: #{e.message}")
  end

end
