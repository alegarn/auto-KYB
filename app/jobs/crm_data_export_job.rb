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
      
      # Prepare data (dummy implementation for now)
      data = {
        name: client.name,
        email: client.email,
        company: client.company_name
      }
      
      # Save payload snapshot for idempotency and tracking
      transfer.update!(payload_snapshot: data.slice(:name, :email, :company))

      # Prepare files (dummy implementation for now)
      files = client.uploaded_files.to_a

      # Perform export
      result = service.export_data(client, data, files)

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
