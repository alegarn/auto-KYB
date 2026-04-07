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

    object_type = mapping[:object_type].presence || "contact"
    property_name = mapping[:property_name].downcase.gsub(/[^a-z0-9_]/, "_")
    options = Array(mapping[:options])
    allow_multiple = mapping[:allow_multiple]

    hs_type, hs_field_type, hs_options = derive_hubspot_property(mapping[:field_type].to_s, options, allow_multiple)

    group_name = object_type == "company" ? "companyinformation" : "contactinformation"

    body = {
        groupName: group_name,
        name: property_name,
        label: mapping[:label],
        type: hs_type,
        fieldType: hs_field_type
    }
    body[:options] = hs_options if hs_options.any?

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

  def derive_hubspot_property(field_type, options, allow_multiple)
    case field_type
    when "number"
      [ "number", "number", [] ]
    when "date"
      [ "date", "date", [] ]
    when "textarea", "long_text"
      [ "string", "textarea", [] ]
    when "select"
      if options.any?
        [ "enumeration", "select", Crm::Hubspot::OptionNormalizer.build_options(options) ]
      else
        [ "string", "text", [] ]
      end
    when "radio"
      if options.any?
        [ "enumeration", "radio", Crm::Hubspot::OptionNormalizer.build_options(options) ]
      else
        [ "string", "text", [] ]
      end
    when "checkbox", "buttons"
      if options.any?
        hs_field_type = allow_multiple ? "checkbox" : "select"
        [ "enumeration", hs_field_type, Crm::Hubspot::OptionNormalizer.build_options(options) ]
      else
        [ "string", "text", [] ]
      end
    else
      [ "string", "text", [] ]
    end
  end

end
