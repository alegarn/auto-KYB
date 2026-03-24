module Crm
  class ExportPayloadBuilder
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
        files: @client.uploaded_files.available.to_a
      )
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
  end
end