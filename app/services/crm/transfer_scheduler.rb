module Crm
  class TransferScheduler
    def self.retry!(transfer)
      new(
        client: transfer.client,
        connection: transfer.crm_connection,
        trigger: transfer.trigger,
        request_context: transfer.retry_request_context
      ).schedule_export!
    end

    def initialize(client:, connection:, trigger:, request_context: {})
      @client = client
      @connection = connection
      @trigger = trigger
      @request_context = request_context || {}
    end

    def schedule_export!
      transfer = CrmTransfer.create!(
        client: @client,
        crm_connection: @connection,
        direction: "export",
        status: CrmTransfer::STATUS_PENDING,
        trigger: @trigger,
        attempts_count: 0,
        request_context: @request_context.deep_stringify_keys
      )

      CrmDataExportJob.perform_later(transfer.id)
      transfer
    end
  end
end