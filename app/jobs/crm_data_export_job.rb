class CrmDataExportJob < ApplicationJob

  queue_as :default

  # Retry logic with exponential backoff (30s, 2min, 10min)
  retry_on StandardError, wait: ->(executions) { [ 30, 120, 600 ][[ [ executions - 1, 0 ].max, 2 ].min] }, attempts: 3

  # Discard on OAuth errors (non-retryable without user intervention)
  discard_on Crm::Hubspot::OAuthError

  def perform(transfer_id)
    transfer = CrmTransfer.find(transfer_id)
    client = transfer.client
    connection = transfer.crm_connection
    mark_processing!(transfer)
    entitlement = Crm::Entitlement.new(client.user)
    unless entitlement.allowed?
      mark_authorization_failed!(transfer, entitlement.reason)
      return
    end

    service = Crm::ConnectionManager.service_for(connection)

    if transfer.trigger == CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC
      begin
        result = Crm::ClientCreateSyncExecutor.new(
          client: client,
          connection: connection,
          service: service,
          request_context: transfer.request_context.to_h
        ).call
        mark_success!(transfer, { external_id: result[:external_contact_id] })
      rescue Crm::Hubspot::OAuthError => e
        mark_failed!(transfer, failure_kind: CrmTransfer::FAILURE_KIND_AUTHENTICATION_ERROR, error_message: e.message) if transfer
        # do not re-raise OAuth errors; treat as discarded
      rescue => e
        mark_failed!(transfer, failure_kind: failure_kind_from_exception(e), error_message: e.message) if transfer
        raise e
      end
    else
      client_form_id = transfer.request_context["client_form_id"]
      payload = Crm::ExportPayloadBuilder.new(client, provider: connection.provider, client_form_id: client_form_id).build

      transfer.update!(payload_snapshot: { contact_data: payload.contact_data, company_data: payload.company_data })

      result = service.export_data(client, payload.contact_data, payload.files, company_data: payload.company_data)

      if result[:success]
        mark_success!(transfer, result)
      else
        mark_failed!(
          transfer,
          failure_kind: failure_kind_from_result(result),
          error_message: result[:error] || "Unknown error occurred during export"
        )
      end
    end
  rescue StandardError => e
    if e.is_a?(Crm::Hubspot::OAuthError)
      mark_failed!(transfer, failure_kind: CrmTransfer::FAILURE_KIND_AUTHENTICATION_ERROR, error_message: e.message) if transfer
      return
    end

    mark_failed!(transfer, failure_kind: failure_kind_from_exception(e), error_message: e.message) if transfer
    raise e # Re-raise to trigger ActiveJob retry
  end

  private

  def mark_processing!(transfer)
    transfer.update!(
      status: CrmTransfer::STATUS_PROCESSING,
      attempts_count: transfer.attempts_count.to_i + 1,
      last_attempt_at: Time.current
    )
  end

  def mark_success!(transfer, result)
    transfer.update!(
      status: CrmTransfer::STATUS_SUCCESS,
      transferred_at: Time.current,
      external_id: result[:external_id].presence || transfer.external_id,
      error_message: nil,
      failure_kind: nil
    )
  end

  def mark_failed!(transfer, failure_kind:, error_message:)
    transfer.update!(
      status: CrmTransfer::STATUS_FAILED,
      failure_kind: failure_kind,
      error_message: error_message,
      transferred_at: nil
    )
  end

  def mark_authorization_failed!(transfer, reason)
    mark_failed!(
      transfer,
      failure_kind: CrmTransfer::FAILURE_KIND_AUTHORIZATION_ERROR,
      error_message: "CRM access denied: #{reason}"
    )
  end

  def failure_kind_from_result(result)
    failure_kind = result[:failure_kind].presence
    return failure_kind if CrmTransfer::FAILURE_KINDS.include?(failure_kind)

    CrmTransfer::FAILURE_KIND_PROVIDER_ERROR
  end

  def failure_kind_from_exception(error)
    case error
    when ActiveRecord::RecordInvalid, ActiveModel::ValidationError
      CrmTransfer::FAILURE_KIND_VALIDATION_ERROR
    else
      CrmTransfer::FAILURE_KIND_UNKNOWN_ERROR
    end
  end

end
