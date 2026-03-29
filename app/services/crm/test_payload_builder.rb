module Crm
  class TestPayloadBuilder
    # Build test contact data, company data, and field_metadata for a test CRM export.
    #
    # @param fields [Array<Hash>]          Form structure fields from form.structure["fields"]
    # @param crm_properties [Hash]         Inertia crmProperties hash { provider => { object_type => [props] } }
    # @param provider [String]             "hubspot" etc.
    # @return [Hash]                       { contact:, company:, field_metadata: }
    def self.build(fields:, crm_properties:, provider:)
      contact_data   = {}
      company_data   = {}
      field_metadata = {}

      fields.each do |field|
        next if layout_field?(field)

        mapping = field.dig("metadata", "crm_mapping", provider)
        next unless mapping

        raw_prop = mapping["property_name"].to_s
        next if raw_prop.blank?

        object_type, prop_name = parse_compound_key(raw_prop, mapping["object_type"])
        crm_prop = find_crm_property(crm_properties, provider, object_type, prop_name)

        value = generate_test_value(field, crm_prop)
        target = (object_type == "company") ? company_data : contact_data
        target[prop_name] = value

        # Populate field_metadata for the ensure_properties path
        options = field.dig("metadata", "options") || []
        if options.any? && choice_field?(field["field_type"])
          field_metadata[prop_name] = {
            field_type:     field["field_type"],
            options:        options,
            allow_multiple: field.dig("metadata", "allow_multiple") || false,
            object_type:    object_type
          }
        end
      end

      { contact: contact_data, company: company_data, field_metadata: field_metadata }
    end

    private

    def self.generate_test_value(field, crm_prop)
      # Enum property with known options — use real values
      if crm_prop && crm_prop[:type] == "enumeration" && crm_prop[:options]&.any?
        if crm_prop[:field_type] == "checkbox"
          crm_prop[:options].first(2).map { |o| o[:value] }.join(";")
        else
          crm_prop[:options].first[:value]
        end
      elsif field["field_type"] == "number"
        rand(1..100).to_s
      elsif field["field_type"] == "date"
        Date.today.iso8601
      elsif field["field_type"] == "checkbox"
        options = field.dig("metadata", "options") || []
        if options.any?
          field.dig("metadata", "allow_multiple") ? options.first(2).join(";") : options.first.to_s
        else
          "Test #{field['label']}"
        end
      elsif %w[select radio buttons].include?(field["field_type"])
        first = (field.dig("metadata", "options") || []).first
        first.present? ? first.to_s : "Test #{field['label']}"
      else
        "Test #{field['label']}"
      end
    end

    def self.find_crm_property(crm_properties, provider, object_type, prop_name)
      props = crm_properties.dig(provider, object_type) ||
              crm_properties.dig(provider.to_sym, object_type.to_sym) || []
      match = props.find { |p| p[:name] == prop_name || p["name"] == prop_name }
      return nil unless match
      # Normalize to symbol keys
      {
        type:       match[:type] || match["type"],
        field_type: match[:field_type] || match["field_type"],
        options:   (match[:options] || match["options"] || []).map do |o|
          { label: o[:label] || o["label"], value: o[:value] || o["value"] }
        end
      }
    end

    def self.parse_compound_key(raw_prop, fallback_object_type)
      if raw_prop.include?("::")
        parts = raw_prop.split("::", 2)
        [parts[0], parts[1]]
      else
        [fallback_object_type || "contact", raw_prop]
      end
    end

    def self.layout_field?(field)
      %w[section subtitle static_text separator logo].include?(field["field_type"])
    end

    def self.choice_field?(field_type)
      %w[select radio checkbox buttons].include?(field_type)
    end
  end
end
