module Crm
  class ExportPayloadBuilder
    Payload = Struct.new(:data, :files, keyword_init: true)

    def initialize(client)
      @client = client
    end

    def build
      Payload.new(
        data: build_data,
        files: @client.uploaded_files.available.to_a
      )
    end

    private

    def build_data
      return {} unless latest_response && latest_client_form

      response_data = latest_response.data || {}

      latest_client_form.form.form_fields.order(:position).each_with_object({}) do |field, payload|
        next if layout_field?(field.field_type)

        value = response_data[field.id.to_s] || response_data[field.id]
        next if value.blank?

        key = field.metadata&.dig("export_key").presence || field.label
        payload[key] = value
      end
    end

    def latest_client_form
      @latest_client_form ||= @client.client_forms.includes(form: :form_fields, form_responses: []).order(created_at: :desc).first
    end

    def latest_response
      @latest_response ||= latest_client_form&.form_responses&.order(created_at: :desc)&.last
    end

    def layout_field?(field_type)
      type = field_type.to_s
      type.start_with?("lay_") || type.start_with?("section") || type == "layout" || type == "title"
    end
  end
end