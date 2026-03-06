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
    object_type = mapping[:object_type].presence || "contact"
    property_name = mapping[:property_name].downcase.gsub(/[^a-z0-9_]/, "_")

    hs_type = "string"
    hs_field_type = "text"

    case mapping[:field_type].to_s
    when "number"
      hs_type = "number"
      hs_field_type = "number"
    when "date"
      hs_type = "date"
      hs_field_type = "date"
    when "long_text", "textarea"
      hs_type = "string"
      hs_field_type = "textarea"
    when "checkbox"
      hs_type = "enumeration"
      hs_field_type = "checkbox"
    when "radio"
      hs_type = "enumeration"
      hs_field_type = "radio"
    when "boolean"
      hs_type = "bool"
      hs_field_type = "booleancheckbox"
    end
    
    if ["checkbox", "radio"].include?(mapping[:field_type].to_s)
      # Fallback to string if enumerations since we don't have options passed easily right now
      hs_type = "string"
      hs_field_type = "text"
    end

    group_name = object_type == "company" ? "companyinformation" : "contactinformation"

    body = {
        groupName: group_name,
        name: property_name,
        label: mapping[:label],
        type: hs_type,
        fieldType: hs_field_type
    }

    begin
      client.sdk.crm.properties.core_api.create(
        object_type: object_type,
        property_create: body
      )
      Rails.logger.info("[HubSpot] Created custom property #{property_name} for #{object_type}")
    rescue StandardError => e
      return if e.message.include?("already exists")
      Rails.logger.error("[HubSpot] Failed to create property: #{e.message}")
    end
  end

end
