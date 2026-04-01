require "rails_helper"

RSpec.describe ClientProfileSyncJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:user) { create(:user) }
    let(:client) { create(:client, user: user) }

    it 'delegates to Crm::ClientProfileSyncService when client exists' do
      expect(Crm::ClientProfileSyncService).to receive(:call).with(client, changed_attribute_keys: [])
      described_class.perform_now(client.id)
    end

    it 'passes changed_attribute_keys to ClientProfileSyncService' do
      changed_keys = %w[name email]
      expect(Crm::ClientProfileSyncService).to receive(:call).with(client, changed_attribute_keys: changed_keys)
      described_class.perform_now(client.id, changed_keys)
    end

    it 'does nothing when the client does not exist' do
      expect(Crm::ClientProfileSyncService).not_to receive(:call)
      described_class.perform_now(99_999_999)
    end

    it 'is queued on the default queue' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'can be enqueued with a client_id' do
      expect {
        described_class.perform_later(client.id, [])
      }.to have_enqueued_job(described_class).with(client.id, anything)
    end
  end
end
