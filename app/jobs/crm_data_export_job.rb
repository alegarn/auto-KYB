class CrmDataExportJob < ApplicationJob

  queue_as :default

  # Retry logic with exponential backoff (30s, 2min, 10min)
  retry_on StandardError, wait: ->(executions) { [30, 120, 600][[[executions - 1, 0].max, 2].min] }, attempts: 3

  # Discard on OAuth errors (non-retryable without user intervention)
  discard_on Crm::Hubspot::OAuthError

  def perform(transfer_id)
    transfer = CrmTransfer.find(transfer_id)
    client = transfer.client
    connection = transfer.crm_connection
    mark_processing!(transfer)
    service = Crm::ConnectionManager.service_for(connection)

    if transfer.trigger == CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC
      begin
        context = transfer.request_context.to_h
        sync_address = ActiveRecord::Type::Boolean.new.cast(context['sync_address_to_contact'])
        external_company_id = context['external_company_id'].presence

        # 1. Create contact
        contact_result = service.create_contact(client, sync_address_to_contact: sync_address)
        puts "[CrmDataExportJob] create_contact result: #{contact_result.inspect}"
        external_contact_id = contact_result && contact_result[:id].presence
        puts "[CrmDataExportJob] external_contact_id: #{external_contact_id.inspect}"

        if external_contact_id.present?
          link = CrmClientLink.find_or_initialize_by(client: client, crm_connection: connection)
          link.external_contact_id = external_contact_id
          link.save!
        end

        # 2. Resolve or create company id
        company_id = external_company_id
        if company_id.blank? && client.company_name.present?
          begin
            found = service.search_companies(client.company_name) || []
            puts "[CrmDataExportJob] search_companies result: #{found.inspect}"
            if found.any?
              exact = found.find { |c| c[:company_name].to_s.casecmp?(client.company_name) }
              company_id = exact[:hubspot_id] || exact[:id] if exact
            end
            puts "[CrmDataExportJob] company_id after search: #{company_id.inspect}"
          rescue NoMethodError
            # provider doesn't support searching companies; continue
          end

          if company_id.blank?
            begin
              created = service.create_company(client, {})
              company_id = created[:id] if created
            rescue NoMethodError
              # provider doesn't support create_company; continue
            end
          end
        end

          if company_id.present?
          link = CrmClientLink.find_or_initialize_by(client: client, crm_connection: connection)
          link.external_company_id = company_id
          link.save!
            puts "[CrmDataExportJob] saved external_company_id=#{company_id.inspect}"
        end

        # 3. Associate if possible
        if external_contact_id.present? && company_id.present?
          puts "[CrmDataExportJob] attempting to associate contact #{external_contact_id} to company #{company_id}"
          begin
            assoc_result = service.associate_contact_to_company(external_contact_id, company_id)
            puts "[CrmDataExportJob] associate returned: #{assoc_result.inspect}"
          rescue NoMethodError
            puts "[CrmDataExportJob] provider missing associate_contact_to_company"
            # provider doesn't support association; ignore
          rescue => e
            puts "[CrmDataExportJob] associate raised: #{e.class} #{e.message}"
            raise
          end
        end

        mark_success!(transfer, { external_id: external_contact_id })
      rescue Crm::Hubspot::OAuthError => e
        mark_failed!(transfer, failure_kind: CrmTransfer::FAILURE_KIND_AUTHENTICATION_ERROR, error_message: e.message) if transfer
        # do not re-raise OAuth errors; treat as discarded
      rescue => e
        mark_failed!(transfer, failure_kind: failure_kind_from_exception(e), error_message: e.message) if transfer
        raise e
      end
    else
      payload = Crm::ExportPayloadBuilder.new(client).build

      transfer.update!(payload_snapshot: payload.data)

      result = service.export_data(client, payload.data, payload.files)

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
