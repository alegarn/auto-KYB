require 'rails_helper'

RSpec.describe CrmDataExportJob, type: :job do
  describe '#perform' do
    let(:client) { create(:client) }
    let(:connection) { create(:crm_connection) }
    let!(:transfer) { create(:crm_transfer, client: client, crm_connection: connection, status: 'pending') }

    it 'marks transfer as success when service returns success' do
      service = double(export_data: { success: true, external_id: 'ext_123' })
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq('success')
      expect(transfer.transferred_at).not_to be_nil
      expect(transfer.error_message).to be_nil
    end

    it 'marks transfer as failed when service returns failure' do
      service = double(export_data: { success: false, error: 'remote error' })
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq('failed')
      expect(transfer.error_message).to match(/remote error/)
    end

    it 'marks transfer failed and re-raises when service raises' do
      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
      allow(service).to receive(:export_data).and_raise(StandardError.new('boom'))

      expect { described_class.perform_now(transfer.id) }.to raise_error(StandardError)

      transfer.reload
      expect(transfer.status).to eq('failed')
      expect(transfer.error_message).to match(/boom/)
    end
  end
end
