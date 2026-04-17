# frozen_string_literal: true

require "set"

module Crm
  class AiFieldMapper

    class PropertyFetchError < StandardError; end

    Result = Data.define(:suggestions, :unmapped_count, :error)

    CRM_OBJECT_LABELS = {
      "hubspot" => { "contact" => "Contact", "company" => "Company" },
      "salesforce" => { "contact" => "Lead", "company" => "Account" },
      "zoho" => { "contact" => "Contact", "company" => "Account" }
    }.freeze
    PROVIDER_FILE_ACTIONS = {
      "hubspot" => {
        "contact" => [ { value: "__note_attachment__", label: "Attach uploaded file to Contact via note attachment" } ],
        "company" => [ { value: "__note_attachment__", label: "Attach uploaded file to Company via note attachment" } ]
      },
      "salesforce" => {
        "contact" => [ { value: "__content_version__", label: "Attach uploaded file to Contact via ContentVersion" } ],
        "company" => [ { value: "__content_version__", label: "Attach uploaded file to Account via ContentVersion" } ]
      },
      "zoho" => {
        "contact" => [ { value: "__attachment__", label: "Attach uploaded file to Contact" } ],
        "company" => [ { value: "__attachment__", label: "Attach uploaded file to Account" } ]
      }
    }.freeze
    CHOICE_FIELD_TYPES = %w[select radio checkbox buttons].freeze
    LAYOUT_FIELD_TYPES = %w[section subtitle static_text separator logo].freeze
    GENERIC_COMPATIBILITY_MAP = {
      "single_choice" => %w[enumeration string text textarea email phone url select radio],
      "multi_choice" => %w[enumeration string text checkbox],
      "string" => %w[string text textarea email phone url select radio],
      "number" => %w[number integer float decimal price],
      "boolean" => %w[boolean bool checkbox yesno enumeration],
      "date" => %w[date datetime],
      "file" => %w[file string text url],
      "json" => %w[string text textarea json],
      "unknown" => %w[string text]
    }.freeze
    MAX_OPTION_COUNT = 20

    def initialize(form:, connection:, unmapped_fields:, already_mapped:, draft_fields: nil, provider:)
      @form = form
      @connection = connection
      @provider = provider.to_s.presence || connection.provider.to_s
      @unmapped_fields = normalize_unmapped_fields(unmapped_fields)
      @already_mapped = Array(already_mapped)
      @draft_fields = normalize_draft_fields(draft_fields)
      @form_fields_by_id = form.form_fields.index_by { |field| field.id.to_s }
      @draft_fields_by_id = @draft_fields.index_by { |field| field["id"] }
    end

    def call
      return empty_result if unmapped_fields.empty?

      filtered_properties = fetch_available_properties

      raw_response = GeminiClient.generate_text(
        system_prompt: system_prompt,
        user_prompt: build_prompt_context(filtered_properties)
      )
      parsed = FormJsonExtractor.call(raw_response)
      validated = validate_suggestions(parsed, filtered_properties)

      Result.new(
        suggestions: validated,
        unmapped_count: unmapped_fields.size - validated.size,
        error: nil
      )
    rescue GeminiClient::ApiError, FormJsonExtractor::ExtractionError, PropertyFetchError => e
      Rails.logger.error("[AiFieldMapper] #{e.class}: #{e.message}")
      Result.new(suggestions: {}, unmapped_count: unmapped_fields.size, error: :ai_unavailable)
    end

    private

    attr_reader :form, :connection, :provider, :unmapped_fields, :already_mapped, :draft_fields, :form_fields_by_id, :draft_fields_by_id

    def empty_result
      Result.new(suggestions: {}, unmapped_count: 0, error: nil)
    end

    def fetch_available_properties
      service = Crm::ConnectionManager.service_for(connection)
      cached_properties = filter_available_properties(service.fetch_properties(force: false))
      return cached_properties unless cached_properties.values.all?(&:empty?)

      filter_available_properties(service.fetch_properties(force: true))
    rescue StandardError => e
      raise PropertyFetchError, e.message
    end

    def filter_available_properties(properties)
      %w[contact company].index_with do |object_type|
        Array(properties[object_type] || properties[object_type.to_sym]).filter_map do |property|
          normalized = normalize_property(property)
          next if normalized[:name].blank?
          next if normalized[:read_only]
          next if already_mapped_property?(object_type, normalized[:name])

          normalized.merge(object_type: object_type)
        end
      end
    end

    def build_prompt_context(properties)
      prompt_sections = [
        "## Form Structure",
        render_form_sections,
        "## Fields Needing Suggestions",
        render_unmapped_fields,
      ]

      if unmapped_fields.any? { |field| file_field?(field) }
        file_actions = render_available_file_actions
        if file_actions.present?
          prompt_sections << "## Available File Actions"
          prompt_sections << file_actions
        end
      end

      prompt_sections << "## Available CRM Properties"
      prompt_sections << render_available_properties(properties)

      prompt_sections.join("\n\n")
    end

    def system_prompt
      <<~PROMPT
        You are a CRM field mapping assistant. Given a list of form fields and available CRM properties, suggest the best CRM property for each form field.

        RULES:
        - Only suggest properties from the provided list. Never invent property names.
        - Respect type compatibility:
          - text/email/textarea fields -> string/text/phone/url properties
          - select/radio fields -> enumeration/string properties
          - checkbox/buttons (multi) fields -> multi-value enumeration properties
          - number fields -> number/integer/decimal properties
          - date fields -> date/datetime properties
          - file fields -> file action tokens from the provided file action list, or file/url/string properties when the goal is storing a file reference
        - Use the form structure (sections, titles, helper text) to decide if a field belongs to a #{object_label("contact")} or #{object_label("company")} object.
        - For file fields, a file action token is a valid property_name even though it is not a normal CRM property.
        - Do not suggest creating a custom property for a file field when a relevant file action token is available for the correct object.
        - If no reasonable existing match exists, you may suggest creating a custom property.
        - Return JSON only, with no markdown or commentary.

        OUTPUT FORMAT:
        {
          "<field_id>": {
            "object_type": "contact" | "company",
            "property_name": "<exact property name from the list or exact file action token from the file action list>" | null,
            "confidence": "high" | "medium",
            "reason": "<brief explanation>",
            "suggest_custom": true | false,
            "suggested_custom_name": "<snake_case_name>"
          }
        }

        Only include fields that need a suggestion.
      PROMPT
    end

    def validate_suggestions(parsed, properties)
      return {} unless parsed.is_a?(Hash)

      available_properties = build_property_lookup(properties)

      parsed.each_with_object({}) do |(field_id, suggestion), validated|
        next unless suggestion.is_a?(Hash)

        field = unmapped_fields_by_id[field_id.to_s]
        next unless field

        object_type = suggestion["object_type"].to_s
        next unless %w[contact company].include?(object_type)

        if ActiveModel::Type::Boolean.new.cast(suggestion["suggest_custom"]) && suggestion["property_name"].nil?
          custom_name = suggestion["suggested_custom_name"].to_s.parameterize(separator: "_").truncate(50)
          next if custom_name.blank?
          next if file_field?(field) && file_actions_available_for?(object_type)

          validated[field["id"]] = compact_suggestion_hash(
            object_type: object_type,
            property_name: nil,
            confidence: normalize_confidence(suggestion["confidence"]),
            reason: normalize_reason(suggestion["reason"]),
            suggest_custom: true,
            suggested_custom_name: custom_name
          )
          next
        end

        property_name = suggestion["property_name"].to_s
        next if property_name.blank?

        if file_action_suggestion?(field, object_type, property_name)
          validated[field["id"]] = compact_suggestion_hash(
            object_type: object_type,
            property_name: property_name,
            confidence: normalize_confidence(suggestion["confidence"]),
            reason: normalize_reason(suggestion["reason"])
          )
          next
        end

        property = available_properties[Crm::KeyParser.build(object_type, property_name)]
        next unless property
        next unless type_compatible?(field, property)

        validated[field["id"]] = compact_suggestion_hash(
          object_type: object_type,
          property_name: property_name,
          confidence: normalize_confidence(suggestion["confidence"]),
          reason: normalize_reason(suggestion["reason"])
        )
      end
    end

    def normalize_unmapped_fields(raw_fields)
      Array(raw_fields).filter_map do |field|
        hash = if field.respond_to?(:to_unsafe_h)
          field.to_unsafe_h
        elsif field.respond_to?(:to_h)
          field.to_h
        else
          field
        end
        next unless hash.is_a?(Hash)

        id = hash["id"] || hash[:id]
        next if id.blank?

        {
          "id" => id.to_s,
          "label" => sanitize_label(hash["label"] || hash[:label]),
          "field_type" => (hash["field_type"] || hash[:field_type]).to_s
        }
      end
    end

    def normalize_property(property)
      hash = property.respond_to?(:to_h) ? property.to_h : property
      return { name: nil, label: nil, type: nil, field_type: nil, read_only: false, options: [] } unless hash.is_a?(Hash)

      {
        name: (hash[:name] || hash["name"]).to_s,
        label: sanitize_label(hash[:label] || hash["label"]),
        type: (hash[:type] || hash["type"]).to_s.downcase,
        field_type: (hash[:field_type] || hash["field_type"]).to_s.downcase.presence,
        read_only: ActiveModel::Type::Boolean.new.cast(hash[:read_only] || hash["read_only"]),
        options: normalize_options(hash[:options] || hash["options"])
      }
    end

    def normalize_options(options)
      Array(options).first(MAX_OPTION_COUNT).filter_map do |option|
        case option
        when Hash
          label = sanitize_label(option[:label] || option["label"] || option[:value] || option["value"])
          next if label.blank?

          { label: label, value: (option[:value] || option["value"] || label).to_s }
        else
          label = sanitize_label(option)
          next if label.blank?

          { label: label, value: label }
        end
      end
    end

    def normalize_already_mapped
      @normalize_already_mapped ||= begin
        compound = Set.new
        raw = Set.new

        already_mapped.each do |value|
          key = value.to_s
          next if key.blank?

          if Crm::KeyParser.compound?(key)
            next if pseudo_file_action?(Crm::KeyParser.property_name(key))

            compound << key
            next
          end

          if key.include?(":")
            object_type, property_name = key.split(":", 2)
            if %w[contact company].include?(object_type) && property_name.present?
              next if pseudo_file_action?(property_name)

              compound << Crm::KeyParser.build(object_type, property_name)
              next
            end
          end

          next if pseudo_file_action?(key)

          raw << key
        end

        { compound: compound, raw: raw }
      end
    end

    def already_mapped_property?(object_type, property_name)
      return false if pseudo_file_action?(property_name)

      compound_key = Crm::KeyParser.build(object_type, property_name)
      normalize_already_mapped[:compound].include?(compound_key) || normalize_already_mapped[:raw].include?(property_name)
    end

    def pseudo_file_action?(property_name)
      Crm::ExportPayloadBuilder.pseudo_file_action?(property_name)
    end

    def available_file_actions
      PROVIDER_FILE_ACTIONS.fetch(provider, {})
    end

    def render_available_file_actions
      %w[contact company].filter_map do |object_type|
        actions = Array(available_file_actions[object_type])
        next if actions.empty?

        lines = [ "### #{object_label(object_type)} File Actions" ]
        actions.each do |action|
          lines << %(- #{action[:value]} (label: "#{action[:label]}") )
        end
        lines.join("\n")
      end.join("\n\n").gsub(/ \)$/, ")")
    end

    def file_action_suggestion?(field, object_type, property_name)
      file_field?(field) && Array(available_file_actions[object_type]).any? { |action| action[:value] == property_name }
    end

    def file_actions_available_for?(object_type)
      Array(available_file_actions[object_type]).any?
    end

    def file_field?(field)
      field_data_type(field) == "file"
    end

    def render_form_sections
      sections = build_form_sections
      return "No form structure available." if sections.empty?

      sections.map do |section|
        lines = [ %(### Section: "#{section[:title]}") ]
        section[:context].each do |context_item|
          lines << %(- Context (#{context_item[:type]}): "#{context_item[:text]}")
        end
        section[:fields].each do |field|
          lines << render_field_line(field)
        end
        lines.join("\n")
      end.join("\n\n")
    end

    def render_unmapped_fields
      unmapped_fields.map do |field|
        render_field_line(field_context_for_unmapped_field(field))
      end.join("\n")
    end

    def render_available_properties(properties)
      %w[contact company].map do |object_type|
        lines = [ "### #{object_label(object_type)} Properties" ]
        Array(properties[object_type]).each do |property|
          details = [ "type: #{property[:type]}" ]
          details << "field_type: #{property[:field_type]}" if property[:field_type].present?
          details << %(label: "#{property[:label]}") if property[:label].present?
          lines << %(- #{property[:name]} (#{details.join(', ')}) )
        end
        lines.join("\n")
      end.join("\n\n").gsub(/ \)$/, ")")
    end

    def build_form_sections
      return build_draft_form_sections if draft_fields.any?

      sections = []
      current_section = { title: "Ungrouped Fields", context: [], fields: [] }
      seen_ids = Set.new

      form.form_fields.order(:position).each do |form_field|
        case form_field.field_type
        when "section"
          sections << current_section if current_section[:context].any? || current_section[:fields].any?
          current_section = {
            title: sanitize_label(form_field.label).presence || "Untitled Section",
            context: [],
            fields: []
          }
        when *LAYOUT_FIELD_TYPES
          text = sanitize_label(form_field.label)
          next if text.blank?

          current_section[:context] << { type: form_field.field_type, text: text }
        else
          field_context = field_context_from_form_field(form_field)
          current_section[:fields] << field_context
          seen_ids << field_context[:id]
        end
      end

      sections << current_section if current_section[:context].any? || current_section[:fields].any?

      extra_fields = unmapped_fields.reject { |field| seen_ids.include?(field["id"]) }
      if extra_fields.any?
        sections << {
          title: "Ungrouped Fields",
          context: [],
          fields: extra_fields.map { |field| field_context_for_unmapped_field(field) }
        }
      end

      sections
    end

    def build_draft_form_sections
      sections = []
      current_section = { title: "Ungrouped Fields", context: [], fields: [] }
      seen_ids = Set.new

      draft_fields.each do |field|
        case field["field_type"]
        when "section"
          sections << current_section if current_section[:context].any? || current_section[:fields].any?
          current_section = {
            title: sanitize_label(field["label"]).presence || "Untitled Section",
            context: [],
            fields: []
          }
        when *LAYOUT_FIELD_TYPES
          text = sanitize_label(field["label"])
          next if text.blank?

          current_section[:context] << { type: field["field_type"], text: text }
        else
          field_context = field_context_for_draft_field(field)
          current_section[:fields] << field_context
          seen_ids << field_context[:id]
        end
      end

      sections << current_section if current_section[:context].any? || current_section[:fields].any?

      extra_fields = unmapped_fields.reject { |field| seen_ids.include?(field["id"]) }
      if extra_fields.any?
        sections << {
          title: "Ungrouped Fields",
          context: [],
          fields: extra_fields.map { |field| field_context_for_unmapped_field(field) }
        }
      end

      sections
    end

    def field_context_from_form_field(form_field)
      metadata = normalize_metadata(form_field.metadata)

      {
        id: form_field.id.to_s,
        label: sanitize_label(form_field.label),
        field_type: form_field.field_type,
        export_key: metadata["export_key"].to_s.presence,
        options: normalize_options(metadata["options"]),
        required: form_field.required,
        metadata: metadata
      }
    end

    def field_context_for_draft_field(field)
      metadata = normalize_metadata(field["metadata"])

      {
        id: field["id"],
        label: sanitize_label(field["label"]),
        field_type: field["field_type"],
        export_key: metadata["export_key"].to_s.presence,
        options: normalize_options(metadata["options"]),
        required: ActiveModel::Type::Boolean.new.cast(field["required"]),
        metadata: metadata
      }
    end

    def field_context_for_unmapped_field(field)
      draft_field = draft_fields_by_id[field["id"]]
      persisted_form_field = form_fields_by_id[field["id"]]
      metadata = normalize_metadata(draft_field ? draft_field["metadata"] : persisted_form_field&.metadata)

      {
        id: field["id"],
        label: draft_field ? sanitize_label(draft_field["label"]) : field["label"],
        field_type: draft_field ? draft_field["field_type"] : field["field_type"],
        export_key: metadata["export_key"].to_s.presence,
        options: normalize_options(metadata["options"]),
        required: draft_field ? ActiveModel::Type::Boolean.new.cast(draft_field["required"]) : persisted_form_field&.required,
        metadata: metadata
      }
    end

    def render_field_line(field)
      details = [ "type: #{field[:field_type]}", "id: #{field[:id]}" ]
      details << "export_key: #{field[:export_key]}" if field[:export_key].present?
      details << "required: true" if field[:required]
      if field[:options].any?
        option_values = field[:options].map { |option| %("#{option[:label]}") }.join(", ")
        details << "options: [#{option_values}]"
      end

      %(- Field "#{field[:label]}" (#{details.join(', ')}))
    end

    def build_property_lookup(properties)
      properties.values.flatten.index_by do |property|
        Crm::KeyParser.build(property[:object_type], property[:name])
      end
    end

    def unmapped_fields_by_id
      @unmapped_fields_by_id ||= unmapped_fields.index_by { |field| field["id"] }
    end

    def type_compatible?(field, property)
      data_type = field_data_type(field)
      property_type = property[:type].to_s.downcase
      property_field_type = property[:field_type].to_s.downcase

      if provider == "hubspot"
        return false if property_field_type == "calculation_equation"
        return data_type == "single_choice" if property_field_type == "booleancheckbox"

        if property_type == "enumeration" && property_field_type.present?
          return data_type == "multi_choice" if property_field_type == "checkbox"

          return data_type == "single_choice"
        end
      end

      compatible_types = GENERIC_COMPATIBILITY_MAP[data_type]
      return compatible_types.include?(property_type) if compatible_types

      %w[string text textarea].include?(property_type)
    end

    def field_data_type(field)
      metadata = field_metadata(field)

      case field["field_type"].to_s
      when "select", "radio"
        "single_choice"
      when "checkbox", "buttons"
        metadata["allow_multiple"] == true ? "multi_choice" : "single_choice"
      when "number"
        "number"
      when "date"
        "date"
      when "file"
        "file"
      when "table"
        "json"
      when "text", "email", "textarea"
        "string"
      else
        "unknown"
      end
    end

    def field_metadata(field)
      draft_field = draft_fields_by_id[field["id"]]
      return normalize_metadata(draft_field["metadata"]) if draft_field

      persisted_form_field = form_fields_by_id[field["id"]]
      normalize_metadata(persisted_form_field&.metadata)
    end

    def normalize_draft_fields(raw_fields)
      Array(raw_fields).filter_map do |field|
        hash = if field.respond_to?(:to_unsafe_h)
          field.to_unsafe_h
        elsif field.respond_to?(:to_h)
          field.to_h
        else
          field
        end
        next unless hash.is_a?(Hash)

        id = hash["id"] || hash[:id]
        next if id.blank?

        {
          "id" => id.to_s,
          "label" => sanitize_label(hash["label"] || hash[:label]),
          "field_type" => (hash["field_type"] || hash[:field_type]).to_s,
          "required" => ActiveModel::Type::Boolean.new.cast(hash["required"] || hash[:required]),
          "position" => hash["position"] || hash[:position],
          "metadata" => normalize_metadata(hash["metadata"] || hash[:metadata])
        }
      end
    end

    def normalize_metadata(metadata)
      hash = metadata.respond_to?(:to_h) ? metadata.to_h : metadata
      return {} unless hash.is_a?(Hash)

      hash.deep_stringify_keys
    end

    def object_label(object_type)
      CRM_OBJECT_LABELS.dig(provider, object_type) || object_type.capitalize
    end

    def compact_suggestion_hash(attributes)
      result = attributes.except(:reason)
      result[:reason] = attributes[:reason] if attributes[:reason].present?
      result
    end

    def normalize_confidence(value)
      %w[high medium].include?(value.to_s) ? value.to_s : "medium"
    end

    def normalize_reason(value)
      value.to_s.truncate(200).presence
    end

    def sanitize_label(label)
      label.to_s.gsub(/[^a-zA-Z0-9\s\-_()\/.,?!']/, "").squish.truncate(100)
    end

  end
end
