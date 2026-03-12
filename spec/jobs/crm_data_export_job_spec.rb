require 'rails_helper'

RSpec.describe CrmDataExportJob, type: :job do
  describe '#perform' do
    let(:client) { create(:client, name: 'John', email: 'john@example.com', company_name: 'Acme Corp') }
    let(:connection) { create(:crm_connection, provider: 'hubspot') }
    let!(:transfer) { create(:crm_transfer, client: client, crm_connection: connection, status: 'pending') }

    it 'marks transfer as success when service returns success' do
      service = double('CrmService')
      
      # Now it expects company_data too
      expect(service).to receive(:export_data).with(
        client, 
        hash_including(name: 'John', email: 'john@example.com', company: 'Acme Corp'), 
        anything,
        company_data: {}
      ).and_return({ success: true, external_id: 'ext_123' })

      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq('success')
      expect(transfer.transferred_at).not_to be_nil
      expect(transfer.error_message).to be_nil
      expect(transfer.payload_snapshot).to include(
        'name' => 'John',
        'email' => 'john@example.com',
        'company' => 'Acme Corp'
      )
    end

    it 'splits form_response into contact_data and company_data based on mapping' do
      # Setup client with form structure and form_response
      form = create(:form, structure: {
        "fields" => [
          { "id" => "field_1", "metadata" => { "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "firstname" } } } },
          { "id" => "field_2", "metadata" => { "crm_mapping" => { "hubspot" => { "object_type" => "company", "property_name" => "domain" } } } },
          { "id" => "field_3", "metadata" => { "crm_mapping" => { "salesforce" => { "object_type" => "company", "property_name" => "Website" } } } }
        ]
      })
      
      # Mock form without requiring the method to physically exist on the client model if it's dynamic
      allow(client).to receive(:respond_to?).and_call_original
      allow(client).to receive(:respond_to?).with(:form).and_return(true)
      allow(client).to receive(:respond_to?).with(:form_response).and_return(true)
      client.define_singleton_method(:form) { form }
      client.define_singleton_method(:form_response) {
        {
          "field_1" => "Jane",
          "field_2" => "acme.com",
          "field_3" => "ignored"
        }
      }
      allow_any_instance_of(CrmTransfer).to receive(:client).and_return(client)

      service = double('CrmService')
      
      expect(service).to receive(:export_data).with(
        client, 
        hash_including(name: 'John', email: 'john@example.com', company: 'Acme Corp', 'firstname' => 'Jane'), 
        anything,
        company_data: { 'domain' => 'acme.com' }
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

