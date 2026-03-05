class CrmPropertyCreationJob < ApplicationJob

  queue_as :default

  def perform(user_id, field_mappings)
    user = User.find_by(id: user_id)
    return unless user

    connections = Crm::ConnectionManager.active_connections_for(user)

    field_mappings.each do |mapping|
      provider = mapping[:provider]
      conn = connections.find { |c| c.provider == provider }
      next unless conn

      if provider == "hubspot"
        create_hubspot_property(conn, mapping)
      end
    end
  end

  private

  def create_hubspot_property(connection, mapping)
    client = Crm::Hubspot::Client.new(connection)

    # default to creating contact properties for now, can be expanded to companies based on mapping metadata
    object_type = "contact"
    property_name = mapping[:property_name].downcase.gsub(/[^a-z0-9_]/, "_")

    body = {
        groupName: "contactinformation",
        name: property_name,
        label: mapping[:label],
        type: "string",
        fieldType: "text"
    }

    begin
      client.sdk.crm.properties.core_api.create(
        object_type: object_type,
        property_create: body
      )
      Rails.logger.info("[HubSpot] Created custom property \#{property_name}")
    rescue StandardError => e
      return if e.message.include?("already exists")
      Rails.logger.error("[HubSpot] Failed to create property: \#{e.message}")
    end
  end

end
