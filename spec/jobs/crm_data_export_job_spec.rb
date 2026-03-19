require 'rails_helper'

RSpec.describe CrmDataExportJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:client) { create(:client, user: user, name: 'John', email: 'john@example.com', company_name: 'Acme Corp') }
    let(:connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }
    let(:form) { create(:form, user: user) }
    let!(:client_form) { create(:client_form, client: client, form: form) }
    let!(:mapped_field) { create(:form_field, form: form, label: 'Registration Number', field_type: 'text', position: 1, metadata: { 'export_key' => 'registration_number' }) }
    let!(:response) { FormResponse.create!(client_form: client_form, data: { mapped_field.id.to_s => 'REG-123' }) }
    let!(:uploaded_file) { create(:uploaded_file, client: client, form_response: response, field_key: mapped_field.id.to_s) }
    let!(:transfer) { create(:crm_transfer, client: client, crm_connection: connection, status: 'pending') }

    it 'marks transfer as success when service returns success' do
      service = double('CrmService')

      expect(service).to receive(:export_data).with(
        client,
        { 'registration_number' => 'REG-123' },
        [uploaded_file]
      ).and_return({ success: true, external_id: 'ext_123' })

      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq('success')
      expect(transfer.transferred_at).not_to be_nil
      expect(transfer.error_message).to be_nil
      expect(transfer.payload_snapshot).to eq('registration_number' => 'REG-123')
    end

    it 'uses the same latest client form payload as the manual export flow' do
      service = double('CrmService')

      expect(service).to receive(:export_data).with(
        client,
        { 'registration_number' => 'REG-123' },
        [uploaded_file]
      ).and_return({ success: true })

      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)
    end

    it 'marks transfer as failed when service returns failure' do
      service = double
      allow(service).to receive(:export_data).and_return({ success: false, error: 'remote error' })
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

    it 'discards on Crm::Hubspot::OAuthError and updates transfer status' do
      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
      allow(service).to receive(:export_data).and_raise(Crm::Hubspot::OAuthError.new('invalid grant'))

      # Job discards the error so perform_now should not raise
      described_class.perform_now(transfer.id)
      
      transfer.reload
      expect(transfer.status).to eq('failed')
      expect(transfer.error_message).to include('OAuth error (non-retryable): invalid grant')
    end
  end
end

