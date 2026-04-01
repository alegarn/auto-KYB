require 'rails_helper'

RSpec.describe CrmDataExportJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user, :subscribed, plan: :pro) }
    let(:client) { create(:client, user: user, name: 'John', email: 'john@example.com', company_name: 'Acme Corp') }
    let(:connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }
    let(:form) { create(:form, user: user) }
    let!(:client_form) { create(:client_form, client: client, form: form) }
    let!(:mapped_field) { create(:form_field, form: form, label: 'Registration Number', field_type: 'text', position: 1, metadata: { 'export_key' => 'registration_number' }) }
    let!(:response) { FormResponse.create!(client_form: client_form, data: { mapped_field.id.to_s => 'REG-123' }) }
    let!(:uploaded_file) { create(:uploaded_file, client: client, form_response: response, field_key: mapped_field.id.to_s) }
    let!(:transfer) { create(:crm_transfer, client: client, crm_connection: connection, status: 'pending', trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT) }

    it 'marks transfer as success when service returns success' do
      service = double('CrmService')

      expect(service).to receive(:export_data).with(
        client,
        { 'registration_number' => 'REG-123' },
        [uploaded_file],
        company_data: {}
      ).and_return({ success: true, external_id: 'ext_123' })

      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq('success')
      expect(transfer.transferred_at).not_to be_nil
      expect(transfer.error_message).to be_nil
      expect(transfer.failure_kind).to be_nil
      expect(transfer.attempts_count).to eq(1)
      expect(transfer.last_attempt_at).not_to be_nil
      expect(transfer.payload_snapshot).to eq('contact_data' => { 'registration_number' => 'REG-123' }, 'company_data' => {})
    end

    it 'uses the same latest client form payload as the manual export flow' do
      service = double('CrmService')

      expect(service).to receive(:export_data).with(
        client,
        { 'registration_number' => 'REG-123' },
        [uploaded_file],
        company_data: {}
      ).and_return({ success: true })

      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)
    end

    it 'marks the transfer as processing before dispatching provider work' do
      service = double('CrmService')
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      expect(service).to receive(:export_data).with(anything, anything, anything, company_data: anything) do
        expect(transfer.reload.status).to eq(CrmTransfer::STATUS_PROCESSING)
        { success: true }
      end

      described_class.perform_now(transfer.id)
    end

    it 'marks transfer as failed when service returns failure' do
      service = double
      allow(service).to receive(:export_data).with(anything, anything, anything, company_data: anything).and_return({ success: false, error: 'remote error' })
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq('failed')
      expect(transfer.failure_kind).to eq(CrmTransfer::FAILURE_KIND_PROVIDER_ERROR)
      expect(transfer.attempts_count).to eq(1)
      expect(transfer.last_attempt_at).not_to be_nil
      expect(transfer.error_message).to match(/remote error/)
    end

    it 'marks transfer failed and re-raises when service raises' do
      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
      allow(service).to receive(:export_data) { raise StandardError, 'boom' }

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq('failed')
      expect(transfer.failure_kind).to eq(CrmTransfer::FAILURE_KIND_UNKNOWN_ERROR)
      expect(transfer.attempts_count).to eq(1)
      expect(transfer.error_message).to match(/boom/)
    end

    it 'discards on Crm::Hubspot::OAuthError and updates transfer status' do
      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
      allow(service).to receive(:export_data).with(anything, anything, anything, company_data: anything).and_raise(Crm::Hubspot::OAuthError.new('invalid grant'))

      # Job discards the error so perform_now should not raise
      described_class.perform_now(transfer.id)
      
      transfer.reload
      expect(transfer.status).to eq('failed')
      expect(transfer.failure_kind).to eq(CrmTransfer::FAILURE_KIND_AUTHENTICATION_ERROR)
      expect(transfer.error_message).to include('invalid grant')
      expect(transfer.attempts_count).to eq(1)
    end

    it 'increments retry bookkeeping on each execution attempt' do
      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
      allow(service).to receive(:export_data) { raise StandardError, 'boom' }

      described_class.perform_now(transfer.id)
      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.attempts_count).to eq(2)
      expect(transfer.last_attempt_at).not_to be_nil
    end

    it 'marks the transfer as authorization_error and skips provider work when entitlement is lost before perform' do
      user.update!(plan: :basic, subscription_status: 'active')

      expect(Crm::ConnectionManager).not_to receive(:service_for)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq(CrmTransfer::STATUS_FAILED)
      expect(transfer.failure_kind).to eq(CrmTransfer::FAILURE_KIND_AUTHORIZATION_ERROR)
      expect(transfer.error_message).to include('plan_insufficient')
      expect(transfer.attempts_count).to eq(1)
      expect(transfer.retryable?).to be(false)
    end

    it 'dispatches client_create_sync transfers without using the generic export flow' do
      transfer.update!(
        trigger: CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC,
        request_context: {
          source: 'clients#create',
          sync_address_to_contact: true,
          external_company_id: 'comp_existing'
        }
      )

      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
      allow(service).to receive(:create_contact).and_return({ id: 'ext_123', action: :created })
      allow(service).to receive(:associate_contact_to_company)

      expect(service).not_to receive(:export_data)
      expect(service).to receive(:create_contact).with(client, sync_address_to_contact: true)
      expect(service).to receive(:associate_contact_to_company).with('ext_123', 'comp_existing')

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq(CrmTransfer::STATUS_SUCCESS)
      expect(transfer.external_id).to eq('ext_123')

      link = CrmClientLink.find_by!(client: client, crm_connection: connection)
      expect(link.external_contact_id).to eq('ext_123')
      expect(link.external_company_id).to eq('comp_existing')
    end

    it 'persists discovered CRM ids incrementally when client_create_sync later fails' do
      transfer.update!(trigger: CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC)

      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
      allow(service).to receive(:create_contact).and_return({ id: 'ext_123', action: :created })
      allow(service).to receive(:search_companies).and_return([{ hubspot_id: 'comp_456', company_name: client.company_name }])
      allow(service).to receive(:associate_contact_to_company).and_raise(StandardError.new('association failed'))

      expect(service).to receive(:create_contact).with(client, sync_address_to_contact: nil)
      expect(service).to receive(:search_companies).with(client.company_name)

      described_class.perform_now(transfer.id)

      transfer.reload
      expect(transfer.status).to eq(CrmTransfer::STATUS_FAILED)
      expect(transfer.failure_kind).to eq(CrmTransfer::FAILURE_KIND_UNKNOWN_ERROR)
      expect(transfer.error_message).to include('association failed')

      link = CrmClientLink.find_by!(client: client, crm_connection: connection)
      expect(link.external_contact_id).to eq('ext_123')
      expect(link.external_company_id).to eq('comp_456')
    end

    it 'uses client_form_id from request_context to scope the export payload, not the latest form' do
      form_b = create(:form, user: user)
      form_field_b = create(:form_field, form: form_b, label: 'Alt Field', field_type: 'text', position: 1, metadata: { 'export_key' => 'alt_field' })
      client_form_b = create(:client_form, client: client, form: form_b)
      FormResponse.create!(client_form: client_form_b, data: { form_field_b.id.to_s => 'ALT-VALUE' })

      transfer.update!(request_context: { 'client_form_id' => client_form.id })

      service = double('CrmService')
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)

      expect(service).to receive(:export_data).with(
        client,
        { 'registration_number' => 'REG-123' },
        [uploaded_file],
        company_data: {}
      ).and_return({ success: true })

      described_class.perform_now(transfer.id)
    end
  end
end

