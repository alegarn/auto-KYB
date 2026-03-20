require 'rails_helper'

RSpec.describe Crm::TransferScheduler, type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }

  before { clear_enqueued_jobs }

  it 'creates a pending export transfer with lifecycle defaults and enqueues processing' do
    scheduler = described_class.new(
      client: client,
      connection: connection,
      trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT,
      request_context: { source: 'clients#export_to_crm' }
    )

    expect {
      @transfer = scheduler.schedule_export!
    }.to change(CrmTransfer, :count).by(1)

    expect(@transfer).to have_attributes(
      client: client,
      crm_connection: connection,
      direction: 'export',
      status: CrmTransfer::STATUS_PENDING,
      trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT,
      attempts_count: 0,
      request_context: { 'source' => 'clients#export_to_crm' }
    )
    expect(@transfer.last_attempt_at).to be_nil
    expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }.map { |job| job[:args] }).to contain_exactly([@transfer.id])
  end
end