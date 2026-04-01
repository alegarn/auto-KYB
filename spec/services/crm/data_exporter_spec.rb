require 'rails_helper'

RSpec.describe Crm::DataExporter, type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :subscribed, plan: :pro) }
  let(:client) { create(:client, user: user) }
  let(:scheduler_class) { class_double(Crm::TransferScheduler) }
  let(:scheduler_instance) { instance_double(Crm::TransferScheduler, schedule_export!: true) }

  before { clear_enqueued_jobs }

  it 'creates transfers and enqueues jobs for active connections only' do
    active = create(:crm_connection, user: user, status: 'active')
    _inactive = create(:crm_connection, user: user, status: 'inactive', provider: 'salesforce')

    exporter = described_class.new(client)

    expect {
      exporter.export_to_all_active!
    }.to change { CrmTransfer.count }.by(1)

    expect(enqueued_jobs.select { |j| j[:job] == CrmDataExportJob }).not_to be_empty
  end

  it 'creates a pending transfer record for each active connection' do
    create(:crm_connection, user: user, status: 'active')
    create(:crm_connection, user: user, status: 'active', provider: 'salesforce')

    exporter = described_class.new(client)

    expect {
      exporter.export_to_all_active!
    }.to change { CrmTransfer.where(status: 'pending').count }.by(2)
  end

  it 'delegates transfer creation to the scheduler with the manual export trigger' do
    connection = create(:crm_connection, user: user, status: 'active')
    allow(scheduler_class).to receive(:new).and_return(scheduler_instance)

    exporter = described_class.new(client, scheduler: scheduler_class)

    exporter.export_to_selected!(['hubspot'])

    expect(scheduler_class).to have_received(:new).with(
      client: client,
      connection: connection,
      trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT,
      request_context: {}
    )
    expect(scheduler_instance).to have_received(:schedule_export!)
  end

  it 'returns an explicit unauthorized result and creates no transfers when entitlement is lost' do
    canceled_user = create(:user, :canceled, plan: :pro)
    canceled_client = create(:client, user: canceled_user)
    create(:crm_connection, user: canceled_user, status: 'active')
    allow(scheduler_class).to receive(:new)

    exporter = described_class.new(canceled_client, scheduler: scheduler_class)

    expect {
      result = exporter.export_to_all_active!
      expect(result).to eq(described_class::UNAUTHORIZED)
    }.not_to change(CrmTransfer, :count)

    expect(scheduler_class).not_to have_received(:new)
  end
end
