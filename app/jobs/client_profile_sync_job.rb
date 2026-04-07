class ClientProfileSyncJob < ApplicationJob

  queue_as :default

  def perform(client_id, changed_attribute_keys = [])
    client = Client.find_by(id: client_id)
    return unless client

    Crm::ClientProfileSyncService.call(client, changed_attribute_keys: changed_attribute_keys)
  end

end
