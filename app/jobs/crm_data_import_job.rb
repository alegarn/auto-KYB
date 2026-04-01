class CrmDataImportJob < ApplicationJob

  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(connection_id, options = {})
    connection = CrmConnection.find(connection_id)
    service = Crm::ConnectionManager.service_for(connection)
    user = connection.user

    after_cursor = options["after"]
    page = service.fetch_contacts(limit: 100, after: after_cursor)

    page[:results].each do |contact_data|
      import_contact(user, connection, contact_data)
    end

    # Enqueue next page if there is one
    if page[:paging]&.dig(:next, :after)
      self.class.perform_later(
        connection_id,
        { "after" => page[:paging][:next][:after] }
      )
    end
  end

  private

  def import_contact(user, connection, data)
    client = user.clients.find_or_initialize_by(email: data[:email])
    client.assign_attributes(
      name:         data[:name].presence || client.name || "Imported Contact",
      company_name: data[:company_name].presence || client.company_name || "Unknown",
      phone:        data[:phone].presence || client.phone,
      address:      data[:address].presence || client.address
    )

    if client.new_record? || client.changed?
      client.save!

      CrmTransfer.create!(
        client: client,
        crm_connection: connection,
        status: CrmTransfer::STATUS_SUCCESS,
        trigger: CrmTransfer::TRIGGER_DATA_IMPORT,
        direction: "import",
        external_id: data[:hubspot_id],
        external_type: "contact",
        attempts_count: 1,
        last_attempt_at: Time.current,
        request_context: { source: "crm_import" },
        transferred_at: Time.current
      )
    end
  end

end
