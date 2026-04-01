class CrmTransferSerializer
  def initialize(transfer)
    @transfer = transfer
  end

  def as_json(*)
    {
      id: @transfer.id,
      created_at: @transfer.created_at&.iso8601,
      provider: @transfer.crm_connection.provider,
      status: @transfer.status,
      trigger: @transfer.trigger,
      failure_kind: @transfer.failure_kind,
      error_message: @transfer.error_message,
      attempts_count: @transfer.attempts_count,
      transferred_at: @transfer.transferred_at&.iso8601,
      retryable: @transfer.retryable?,
      client: {
        id: @transfer.client.id,
        name: @transfer.client.name,
        company_name: @transfer.client.company_name
      }
    }
  end

  def self.collection(relation)
    relation.map { |transfer| new(transfer).as_json }
  end
end