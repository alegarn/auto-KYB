# frozen_string_literal: true

module ClientPortal
  class FormResponseSaver

    Result = Struct.new(:response, :merged_data, :conflict, :error, keyword_init: true)

    def initialize(client_form:, data:, validate:, partial:, base_version: nil)
      @client_form = client_form
      @data = data
      @validate = validate
      @partial = partial
      @base_version = base_version
    end

    def save
      data = normalize_data(@data)

      if @partial
        last_response = @client_form.form_responses.order(:version).last
        if @base_version && last_response && last_response.version != @base_version
          return Result.new(
            conflict: true,
            error: "This form was updated elsewhere. Please reload."
          )
        end

        base_data = normalize_data(last_response&.data || {})
        data = base_data.merge(data)
      end

      response = @client_form.save_response!(data: data, validate: @validate)
      
      enqueue_crm_exports(@client_form.client) if @validate
      
      Result.new(response: response, merged_data: data, conflict: false)
    end

    private

    def enqueue_crm_exports(client)
      return unless client.user.can_use_crm? && client.user.crm_auto_sync_on_portal_submit

      Crm::DataExporter.new(client).export_to_all_active!(
        trigger: CrmTransfer::TRIGGER_PORTAL_SUBMIT,
        request_context: {
          source: "client_portal",
          client_form_id: @client_form.id
        }
      )
    rescue StandardError => e
      Rails.logger.error("Failed to enqueue CRM export: #{e.message}")
    end

    def normalize_data(data)
      data = data.to_unsafe_h if data.respond_to?(:to_unsafe_h)
      return {} unless data.is_a?(Hash)
      data.deep_transform_keys(&:to_s)
    end

  end
end
