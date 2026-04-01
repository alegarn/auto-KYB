module Crm
  class DataExporter
    UNAUTHORIZED = :unauthorized

    def initialize(client, scheduler: TransferScheduler)
      @client = client
      @user = client.user
      @scheduler = scheduler
    end

    def export_to_all_active!(trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT, request_context: {})
      enqueue_exports_for(
        ConnectionManager.active_connections_for(@user),
        trigger: trigger,
        request_context: request_context
      )
    end

    def export_to_selected!(providers, trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT, request_context: {})
      selected_providers = Array(providers).map(&:to_s).reject(&:blank?).uniq
      connections = ConnectionManager.active_connections_for(@user).where(provider: selected_providers)

      enqueue_exports_for(connections, trigger: trigger, request_context: request_context)
    end

    private

    def enqueue_exports_for(connections, trigger:, request_context:)
      return UNAUTHORIZED unless Entitlement.new(@user).allowed?

      connections.each do |connection|
        @scheduler.new(
          client: @client,
          connection: connection,
          trigger: trigger,
          request_context: request_context
        ).schedule_export!
      end
    end
  end
end