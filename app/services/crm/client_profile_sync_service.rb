module Crm
  class ClientProfileSyncService

    SYNCED_ATTRIBUTES = %w[name email phone company_name company_id country address].freeze

    Result = Struct.new(:triggered, :reason, keyword_init: true)

    def self.call(client, changed_attribute_keys: nil)
      new(client, changed_attribute_keys: changed_attribute_keys).call
    end

    def initialize(client, changed_attribute_keys: nil)
      @client = client
      @changed_attribute_keys = changed_attribute_keys
    end

    def call
      return Result.new(triggered: false, reason: :not_linked) unless crm_linked?
      return Result.new(triggered: false, reason: :inactive_connection) unless connection_active?
      return Result.new(triggered: false, reason: :no_relevant_changes) unless relevant_changes?

      connection = @client.crm_client_link.crm_connection
      Crm::TransferScheduler.new(
        client: @client,
        connection: connection,
        trigger: CrmTransfer::TRIGGER_CLIENT_EDIT_SYNC,
        request_context: { source: "client_profile_sync" }
      ).schedule_export!
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
      keys = @changed_attribute_keys.nil? ? @client.previous_changes.keys : @changed_attribute_keys
      (Array(keys).map(&:to_s) & SYNCED_ATTRIBUTES).any?
    end

  end
end
