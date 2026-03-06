class CrmDataExportJob < ApplicationJob
  queue_as :default

  # Retry logic with exponential backoff (30s, 2min, 10min)
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Discard on OAuth errors (non-retryable without user intervention)
  discard_on Crm::Hubspot::OAuthError do |job, error|
    transfer = CrmTransfer.find_by(id: job.arguments.first)
    transfer&.update!(status: "failed", error_message: "OAuth error (non-retryable): #{error.message}")
  end

  def perform(transfer_id)
    transfer = CrmTransfer.find(transfer_id)
    client = transfer.client
    connection = transfer.crm_connection

    begin
      service = Crm::ConnectionManager.service_for(connection)
      
      # Prepare contact data
      contact_data = {
        name: client.name,
        email: client.email,
        company: client.company_name
      }

      # Separate company data from form field mappings
      company_data = {}
      form = client.respond_to?(:form) ? client.form : nil
      form_fields = form&.structure&.dig("fields") || []
      form_response = client.respond_to?(:form_response) ? (client.form_response || {}) : {}

      form_fields.each do |field|
        field = field.with_indifferent_access
        mapping = field.dig("metadata", "crm_mapping", connection.provider)
        next unless mapping.present?

        field_value = form_response[field["id"]] || form_response[field["label"]]
        next unless field_value.present?

        prop_name = mapping["property_name"]
        next unless prop_name.present?

        case mapping["object_type"]
        when "company"
          company_data[prop_name] = field_value
        when "contact"
          contact_data[prop_name] = field_value
        end
      end

      # Save payload snapshot for idempotency and tracking
      transfer.update!(payload_snapshot: contact_data.slice(:name, :email, :company))

      # Prepare files
      files = client.uploaded_files.to_a

      # Perform export with separated contact and company data
      result = service.export_data(client, contact_data, files, company_data: company_data)

      if result[:success]
        transfer.update!(
          status: 'success',
          transferred_at: Time.current,
          error_message: nil
        )
      else
        transfer.update!(
          status: 'failed',
          error_message: result[:error] || 'Unknown error occurred during export'
        )
      end
    rescue => e
      transfer.update!(
        status: 'failed',
        error_message: e.message
      )
      raise e # Re-raise to trigger ActiveJob retry
    end
  end
end
