require 'rails_helper'

RSpec.describe Crm::ClientProfileSyncService, type: :service do
  let(:user) { create(:user) }
  let(:connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }
  let(:client) { create(:client, user: user) }

  describe '.call' do
    it 'syncs linked client profile changes by scheduling an async export' do
      create(:crm_client_link, client: client, crm_connection: connection)
      client.update!(phone: '+44 20 7946 0958')

      scheduler = instance_double(Crm::TransferScheduler)
      allow(Crm::TransferScheduler).to receive(:new).with(
        client: client,
        connection: connection,
        trigger: CrmTransfer::TRIGGER_CLIENT_EDIT_SYNC,
        request_context: { source: "client_profile_sync" }
      ).and_return(scheduler)
      allow(scheduler).to receive(:schedule_export!)

      result = described_class.call(client)

      expect(scheduler).to have_received(:schedule_export!)
      expect(result.triggered).to be(true)
      expect(result.reason).to eq(:synced)
    end

    it 'passes changed_attribute_keys to the relevant_changes? guard' do
      create(:crm_client_link, client: client, crm_connection: connection)

      scheduler = instance_double(Crm::TransferScheduler)
      allow(Crm::TransferScheduler).to receive(:new).and_return(scheduler)
      allow(scheduler).to receive(:schedule_export!)

      result = described_class.call(client, changed_attribute_keys: %w[name email])

      expect(scheduler).to have_received(:schedule_export!)
      expect(result.triggered).to be(true)
    end

    it 'skips sync when no CRM-relevant field changed' do
      create(:crm_client_link, client: client, crm_connection: connection)
      client.reload

      expect(Crm::TransferScheduler).not_to receive(:new)

      result = described_class.call(client)

      expect(result.triggered).to be(false)
      expect(result.reason).to eq(:no_relevant_changes)
    end

    it 'skips sync when passed changed_attribute_keys contains no synced attributes' do
      create(:crm_client_link, client: client, crm_connection: connection)

      expect(Crm::TransferScheduler).not_to receive(:new)

      result = described_class.call(client, changed_attribute_keys: %w[form_status])

      expect(result.triggered).to be(false)
      expect(result.reason).to eq(:no_relevant_changes)
    end

    it 'skips sync when the client has no CRM link' do
      expect(Crm::TransferScheduler).not_to receive(:new)

      result = described_class.call(client, changed_attribute_keys: %w[name])

      expect(result.triggered).to be(false)
      expect(result.reason).to eq(:not_linked)
    end

    it 'skips sync when the CRM connection is inactive' do
      inactive_connection = create(:crm_connection, user: user, provider: 'hubspot', status: 'disconnected')
      create(:crm_client_link, client: client, crm_connection: inactive_connection)

      expect(Crm::TransferScheduler).not_to receive(:new)

      result = described_class.call(client, changed_attribute_keys: %w[name])

      expect(result.triggered).to be(false)
      expect(result.reason).to eq(:inactive_connection)
    end
  end
end