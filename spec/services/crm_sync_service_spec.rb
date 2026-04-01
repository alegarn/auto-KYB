require 'rails_helper'

RSpec.describe CrmSyncService do
  include ActiveJob::TestHelper

  let(:client) { create(:client, name: "John Doe", email: "john@example.com", company_name: "Acme Corp", user: user) }
  let(:user) { create(:user, :subscribed, plan: :pro) }
  let(:connection) { create(:crm_connection, user: user, provider: "hubspot", status: 'active') }
  let(:scheduler_class) { class_double(Crm::TransferScheduler) }
  let(:scheduled_transfer) do
    build_stubbed(
      :crm_transfer,
      :client_create_sync,
      client: client,
      crm_connection: connection,
      request_context: {
        source: "clients#create",
        sync_address_to_contact: true,
        external_company_id: "comp_456"
      }
    )
  end
  let(:scheduler_instance) { instance_double(Crm::TransferScheduler, schedule_export!: scheduled_transfer) }

  before do
    clear_enqueued_jobs
  end

  describe '.call' do
    it 'creates a CRM link for the link strategy when entitled' do
      expect(CrmClientLink.find_by(client: client, crm_connection: connection)).to be_nil

      result = described_class.call(client, "link", external_contact_id: "ext123", external_company_id: "comp456")

      link = CrmClientLink.find_by!(client: client, crm_connection: connection)
      expect(result).to eq(link)
      expect(link.external_contact_id).to eq("ext123")
      expect(link.external_company_id).to eq("comp456")
    end

    it 'schedules an async export via TransferScheduler for the create strategy' do
      allow(scheduler_class).to receive(:new).and_return(scheduler_instance)

      result = described_class.call(
        client,
        "create",
        external_company_id: "comp_456",
        sync_address_to_contact: true,
        source: 'clients#create',
        scheduler: scheduler_class
      )

      expect(result).to eq(scheduled_transfer)
      expect(scheduler_class).to have_received(:new).with(
        client: client,
        connection: connection,
        trigger: CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC,
        request_context: {
          source: "clients#create",
          sync_address_to_contact: true,
          external_company_id: "comp_456"
        }
      )
      expect(scheduler_instance).to have_received(:schedule_export!)
      expect(CrmClientLink.count).to eq(0)
    end

    it 'schedules an async export via TransferScheduler for the update strategy' do
      create(:crm_client_link, client: client, crm_connection: connection)
      scheduler_instance2 = instance_double(Crm::TransferScheduler, schedule_export!: nil)
      allow(Crm::TransferScheduler).to receive(:new).and_return(scheduler_instance2)

      described_class.call(client, 'update', sync_address_to_contact: true, source: 'clients#update')

      expect(Crm::TransferScheduler).to have_received(:new).with(
        client: client,
        connection: connection,
        trigger: CrmTransfer::TRIGGER_CLIENT_EDIT_SYNC,
        request_context: hash_including(
          source: 'clients#update',
          sync_address_to_contact: true
        )
      )
      expect(scheduler_instance2).to have_received(:schedule_export!)
    end

    it 'returns an explicit unauthorized result before creating links for non-entitled users' do
      basic_user = create(:user, :subscribed, plan: :basic)
      basic_client = create(:client, user: basic_user)
      create(:crm_connection, user: basic_user, provider: 'hubspot', status: 'active')

      expect {
        result = described_class.call(basic_client, 'link', external_contact_id: 'ext123')
        expect(result).to eq(described_class::UNAUTHORIZED)
      }.not_to change(CrmClientLink, :count)
    end

    it 'returns an explicit unauthorized result before scheduling transfers for non-entitled users' do
      canceled_user = create(:user, :canceled, plan: :pro)
      canceled_client = create(:client, user: canceled_user)
      create(:crm_connection, user: canceled_user, provider: 'hubspot', status: 'active')

      allow(scheduler_class).to receive(:new)

      expect {
        result = described_class.call(canceled_client, 'create', scheduler: scheduler_class)
        expect(result).to eq(described_class::UNAUTHORIZED)
      }.not_to change(CrmTransfer, :count)

      expect(scheduler_class).not_to have_received(:new)
    end
  end
end
