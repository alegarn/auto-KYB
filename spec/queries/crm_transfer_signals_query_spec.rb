require 'rails_helper'

RSpec.describe CrmTransferSignalsQuery do
  around do |example|
    travel_to(Time.zone.parse('2026-03-20 12:00:00 UTC')) do
      example.run
    end
  end

  subject(:signals) { described_class.new(user: user, toast_seen_at: toast_seen_at).call }

  let(:user) { create(:user, :subscribed) }
  let(:connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }
  let(:toast_seen_at) { nil }

  describe '#call' do
    it 'returns zero counts and no toast when the user has no failed transfers' do
      create(
        :crm_transfer,
        :success,
        client: create(:client, user: user),
        crm_connection: connection
      )

      expect(signals).to eq(
        unread_failed_count: 0,
        unread_retryable_count: 0,
        latest_unread_failure_at: nil,
        toast: nil
      )
    end

    it 'counts only failed transfers visible to the current user' do
      visible_transfer = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection
      )

      other_user = create(:user, :subscribed)
      other_connection = create(:crm_connection, user: other_user, provider: 'hubspot', status: 'active')
      create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: other_user),
        crm_connection: other_connection
      )
      create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: create(:crm_connection, user: other_user, provider: 'salesforce', status: 'active')
      )

      expect(signals).to include(
        unread_failed_count: 1,
        unread_retryable_count: 1,
        latest_unread_failure_at: visible_transfer.created_at.iso8601
      )
    end

    it 'ignores transfers older than the retention window' do
      retained_transfer = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 2.days.ago
      )
      create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 4.days.ago
      )

      expect(signals).to include(
        unread_failed_count: 1,
        unread_retryable_count: 1,
        latest_unread_failure_at: retained_transfer.created_at.iso8601
      )
    end

    it 'counts only failures newer than users.crm_transfers_last_seen_at as unread' do
      user.update!(crm_transfers_last_seen_at: 3.hours.ago)

      create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 4.hours.ago
      )
      unread_transfer = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 2.hours.ago
      )

      expect(signals).to include(
        unread_failed_count: 1,
        unread_retryable_count: 1,
        latest_unread_failure_at: unread_transfer.created_at.iso8601
      )
    end

    it 'counts unread retryable failures separately' do
      user.update!(crm_transfers_last_seen_at: 3.hours.ago)

      create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 2.hours.ago
      )
      create(
        :crm_transfer,
        :non_retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 1.hour.ago
      )

      expect(signals).to include(
        unread_failed_count: 2,
        unread_retryable_count: 1
      )
    end

    it 'builds a toast payload when latest unread failure is newer than toast_seen_at' do
      first_failure = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 2.hours.ago
      )
      latest_failure = create(
        :crm_transfer,
        :non_retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 1.hour.ago
      )

      result = described_class.new(user: user, toast_seen_at: first_failure.created_at.iso8601).call

      expect(result).to eq(
        unread_failed_count: 2,
        unread_retryable_count: 1,
        latest_unread_failure_at: latest_failure.created_at.iso8601,
        toast: {
          type: 'alert',
          message: '2 CRM transfers failed. Review them on CRM Transfers.',
          href: '/crm_transfers?status=failed'
        }
      )
    end

    it 'does not build a toast payload when toast_seen_at is already at or after the latest unread failure' do
      latest_failure = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: connection,
        created_at: 1.hour.ago
      )

      result = described_class.new(user: user, toast_seen_at: latest_failure.created_at.iso8601).call

      expect(result).to eq(
        unread_failed_count: 1,
        unread_retryable_count: 1,
        latest_unread_failure_at: latest_failure.created_at.iso8601,
        toast: nil
      )
    end
  end
end
