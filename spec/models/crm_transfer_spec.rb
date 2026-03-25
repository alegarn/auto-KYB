require 'rails_helper'

RSpec.describe CrmTransfer, type: :model do
  describe 'constants' do
    it 'defines the allowed statuses, triggers, and failure kinds' do
      expect(described_class::STATUSES).to contain_exactly('pending', 'processing', 'success', 'failed')
      expect(described_class::TRIGGERS).to include('manual_export', 'portal_submit', 'client_create_sync', 'client_edit_sync', 'data_import')
      expect(described_class::FAILURE_KINDS).to include('authentication_error', 'provider_error', 'validation_error', 'unknown_error')
    end
  end

  describe 'associations' do
    it 'belongs to client and crm_connection' do
      client = create(:client)
      conn = create(:crm_connection)
      transfer = create(:crm_transfer, client: client, crm_connection: conn)

      expect(transfer.client).to eq(client)
      expect(transfer.crm_connection).to eq(conn)
    end
  end

  describe 'validations' do
    it 'allows only known statuses' do
      transfer = build(:crm_transfer, status: 'unknown')

      expect(transfer).not_to be_valid
      expect(transfer.errors[:status]).to include('is not included in the list')
    end

    it 'allows only known triggers' do
      transfer = build(:crm_transfer, trigger: 'unknown')

      expect(transfer).not_to be_valid
      expect(transfer.errors[:trigger]).to include('is not included in the list')
    end
  end

  describe 'scopes' do
    it 'orders newest first' do
      older = create(:crm_transfer, created_at: 2.days.ago)
      newer = create(:crm_transfer, created_at: 1.hour.ago)

      expect(described_class.newest_first).to start_with(newer, older)
    end

    it 'filters by status' do
      failed = create(:crm_transfer, :failed)
      create(:crm_transfer, :success)

      expect(described_class.by_status(CrmTransfer::STATUS_FAILED)).to contain_exactly(failed)
    end

    it 'filters by provider' do
      hubspot = create(:crm_transfer, crm_connection: create(:crm_connection, provider: 'hubspot'))
      create(:crm_transfer, crm_connection: create(:crm_connection, provider: 'salesforce'))

      expect(described_class.by_provider('hubspot')).to contain_exactly(hubspot)
    end

    it 'filters by trigger' do
      portal = create(:crm_transfer, :portal_submit)
      create(:crm_transfer, :manual_export)

      expect(described_class.by_trigger(CrmTransfer::TRIGGER_PORTAL_SUBMIT)).to contain_exactly(portal)
    end

    it 'returns retryable failed transfers only' do
      retryable = create(:crm_transfer, :retryable_failed)
      create(:crm_transfer, :non_retryable_failed)
      create(:crm_transfer, :success)

      expect(described_class.retryable).to contain_exactly(retryable)
    end

    it 'returns transfers older than the three-day retention cutoff' do
      old_transfer = travel_to(4.days.ago) { create(:crm_transfer) }
      create(:crm_transfer)

      expect(described_class.older_than_retention_cutoff).to contain_exactly(old_transfer)
    end
  end

  describe '#retryable?' do
    it 'is true for failed provider errors' do
      expect(build(:crm_transfer, :retryable_failed)).to be_retryable
    end

    it 'is false for authentication failures' do
      expect(build(:crm_transfer, :non_retryable_failed)).not_to be_retryable
    end
  end
end
