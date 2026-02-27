module Crm
  class DataExporter
    def initialize(client)
      @client = client
      @user = client.user
    end

    def export_to_all_active!
      connections = ConnectionManager.active_connections_for(@user)
      
      connections.each do |connection|
        # Create a pending transfer record
        transfer = CrmTransfer.create!(
          client: @client,
          crm_connection: connection,
          status: 'pending'
        )

        # Enqueue the job to process this transfer
        CrmDataExportJob.perform_later(transfer.id)
      end
    end
  end
end