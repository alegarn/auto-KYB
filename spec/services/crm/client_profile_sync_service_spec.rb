require 'rails_helper'

RSpec.describe Crm::ClientProfileSyncService, type: :service do
  let(:user) { create(:user) }
  let(:connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }
  let(:client) { create(:client, user: user) }

  describe '.call' do
    it 'syncs linked client profile changes' do
      create(:crm_client_link, client: client, crm_connection: connection)
      client.update!(phone: '+44 20 7946 0958')

      expect(CrmSyncService).to receive(:call).with(client, 'update')

      result = described_class.call(client)

      expect(result.triggered).to be(true)
      expect(result.reason).to eq(:synced)
    end

    it 'skips sync when no CRM-relevant field changed' do
      create(:crm_client_link, client: client, crm_connection: connection)
      client.reload

      expect(CrmSyncService).not_to receive(:call)

      result = described_class.call(client)

      expect(result.triggered).to be(false)
      expect(result.reason).to eq(:no_relevant_changes)
    end
  end
end