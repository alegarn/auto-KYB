module Crm
  class ClientProfileSyncService

    SYNCED_ATTRIBUTES = %w[name email phone company_name company_id country address].freeze

    Result = Struct.new(:triggered, :reason, keyword_init: true)

    def self.call(client)
      new(client).call
    end

    def initialize(client)
      @client = client
    end

    def call
      return Result.new(triggered: false, reason: :not_linked) unless crm_linked?
      return Result.new(triggered: false, reason: :inactive_connection) unless connection_active?
      return Result.new(triggered: false, reason: :no_relevant_changes) unless relevant_changes?

      CrmSyncService.call(@client, "update")
      Result.new(triggered: true, reason: :synced)
    end

    private

    def crm_linked?
      @client.crm_client_link.present?
    end

    def connection_active?
      @client.crm_client_link&.crm_connection&.status == "active"
    end

    def relevant_changes?
      @client.previous_changes.slice(*SYNCED_ATTRIBUTES).any?
    end

  end
end