module Crm
  class DataExporter
    def initialize(client)
      @client = client
      @user = client.user
    end

    def export_to_all_active!
      enqueue_exports_for(ConnectionManager.active_connections_for(@user))
    end

    def export_to_selected!(providers)
      selected_providers = Array(providers).map(&:to_s).reject(&:blank?).uniq
      connections = ConnectionManager.active_connections_for(@user).where(provider: selected_providers)

      enqueue_exports_for(connections)
    end

    private

    def enqueue_exports_for(connections)
      connections.each do |connection|
        transfer = CrmTransfer.create!(
          client: @client,
          crm_connection: connection,
          status: 'pending'
        )

        CrmDataExportJob.perform_later(transfer.id)
      end
    end
  end
end