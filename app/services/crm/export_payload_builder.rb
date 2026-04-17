module Crm
  class ExportPayloadBuilder

    PSEUDO_FILE_ACTIONS = %w[__note_attachment__ __content_version__ __attachment__].freeze
    FILE_FIELD_TYPE = "file"

    Payload = Struct.new(:contact_data, :company_data, :files, keyword_init: true)

    def initialize(client, provider: nil, client_form_id: nil)
      @client = client
      @provider = provider
      @client_form_id = client_form_id
    end

    def build
      Payload.new(
        contact_data: build_object_data("contact"),
        company_data: build_object_data("company"),
        files: build_file_items
      )
    end

    def self.pseudo_file_action?(action)
      PSEUDO_FILE_ACTIONS.include?(action.to_s)
    end

    private

    def build_object_data(target_object_type)
      return {} unless latest_response && latest_client_form

      response_data = latest_response.data || {}

      latest_client_form.form.form_fields.order(:position).each_with_object({}) do |field, payload|
        next if layout_field?(field.field_type)

        value = response_data[field.id.to_s] || response_data[field.id]
        next if value.blank?

        provider_mapping = @provider && field.metadata&.dig("crm_mapping", @provider)
        raw_property_name = provider_mapping&.dig("property_name")

        # Compound key is the single source of truth for object routing.
        # Fall back to the explicit object_type field for legacy data.
        if raw_property_name.present? && Crm::KeyParser.compound?(raw_property_name)
          parsed_object_type, clean_key = Crm::KeyParser.parse(raw_property_name)
          object_type = parsed_object_type
        else
          object_type = provider_mapping&.dig("object_type") || "contact"
          clean_key = raw_property_name
        end

        next unless object_type == target_object_type

        key = clean_key.presence ||
              field.metadata&.dig("export_key").presence ||
              field.label
        payload[key] = value
      end
    end

    def latest_client_form
      @latest_client_form ||= if @client_form_id.present?
        @client.client_forms.includes(form: :form_fields, form_responses: []).find_by(id: @client_form_id)
      else
        @client.client_forms.includes(form: :form_fields, form_responses: []).order(created_at: :desc).first
      end
    end

    def latest_response
      @latest_response ||= latest_client_form&.form_responses&.order(created_at: :desc)&.first
    end

    def layout_field?(field_type)
      type = field_type.to_s
      type.start_with?("lay_") || type.start_with?("section") || type == "layout" || type == "title"
    end

    # Build file items enriched with CRM mapping context (target + action).
    # Falls back to plain UploadedFile objects when no mapping is available.
    def build_file_items
      available_files = @client.uploaded_files.available.to_a
      return available_files unless latest_client_form && @provider

      mapping_by_field_key = build_file_field_mappings
      return available_files if mapping_by_field_key.empty?

      available_files.map do |uploaded_file|
        mapping = mapping_by_field_key[uploaded_file.field_key]
        next uploaded_file unless mapping

        { file: uploaded_file, target: mapping[:target].to_sym, action: mapping[:action] }
      end
    end

    # Reads CRM mapping metadata from file-type form fields and returns a
    # Hash keyed by form_field.id (the UploadedFile.field_key) with
    # { target: "contact"|"company", action: "__note_attachment__"|property_name }.
    def build_file_field_mappings
      return {} unless latest_client_form && @provider

      latest_client_form.form.form_fields.each_with_object({}) do |field, mappings|
        next unless field.field_type == FILE_FIELD_TYPE

        provider_mapping = field.metadata&.dig("crm_mapping", @provider)
        next unless provider_mapping

        raw_property_name = provider_mapping["property_name"]
        next if raw_property_name.blank?

        if Crm::KeyParser.compound?(raw_property_name)
          object_type, property_name = Crm::KeyParser.parse(raw_property_name)
        else
          object_type = provider_mapping["object_type"] || "contact"
          property_name = raw_property_name
        end

        mappings[field.id.to_s] = { target: object_type, action: property_name }
      end
    end

  end
end
