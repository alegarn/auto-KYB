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
    expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }.map { |job| job[:args] }).to contain_exactly([ @transfer.id ])
  end

  context 'client_create_sync deduplication' do
    let(:trigger) { CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC }

    def build_scheduler
      described_class.new(client: client, connection: connection, trigger: trigger)
    end

    it 'returns an existing pending client_create_sync transfer instead of creating a duplicate' do
      existing = create(:crm_transfer,
        client: client, crm_connection: connection,
        trigger: trigger, status: CrmTransfer::STATUS_PENDING, direction: 'export')

      expect {
        @result = build_scheduler.schedule_export!
      }.not_to change(CrmTransfer, :count)

      expect(@result).to eq(existing)
      expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }).to be_empty
    end

    it 'returns an existing processing client_create_sync transfer instead of creating a duplicate' do
      existing = create(:crm_transfer,
        client: client, crm_connection: connection,
        trigger: trigger, status: CrmTransfer::STATUS_PROCESSING, direction: 'export')

      expect {
        @result = build_scheduler.schedule_export!
      }.not_to change(CrmTransfer, :count)

      expect(@result).to eq(existing)
      expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }).to be_empty
    end

    it 'creates a new transfer when the previous client_create_sync transfer is failed' do
      create(:crm_transfer,
        client: client, crm_connection: connection,
        trigger: trigger, status: CrmTransfer::STATUS_FAILED, direction: 'export')

      expect {
        @result = build_scheduler.schedule_export!
      }.to change(CrmTransfer, :count).by(1)

      expect(@result.status).to eq(CrmTransfer::STATUS_PENDING)
      expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }.size).to eq(1)
    end

    it 'creates a new transfer for triggers other than client_create_sync' do
      create(:crm_transfer,
        client: client, crm_connection: connection,
        trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT,
        status: CrmTransfer::STATUS_PENDING, direction: 'export')

      scheduler = described_class.new(
        client: client, connection: connection,
        trigger: CrmTransfer::TRIGGER_MANUAL_EXPORT
      )

      expect {
        @result = scheduler.schedule_export!
      }.to change(CrmTransfer, :count).by(1)

      expect(@result.status).to eq(CrmTransfer::STATUS_PENDING)
    end
  end
end
