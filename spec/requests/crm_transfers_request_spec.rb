require 'rails_helper'

RSpec.describe 'CrmTransfers', type: :request do
  include ActiveJob::TestHelper

  let(:user) { sign_in_user(create(:user, :subscribed)) }
  let(:session_id) { user.sessions.last.id }
  let(:inertia_headers) do
    {
      'Cookie' => "session_token=#{session_id}",
      'X-Inertia' => 'true',
      'X-Inertia-Version' => ViteRuby.digest
    }
  end
  let(:auth_headers) { { 'Cookie' => "session_token=#{session_id}" } }

  around do |example|
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe 'GET /crm_transfers' do
    it 'renders UI-safe transfer payloads for the current user' do
      transfer = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user, name: 'Jane Doe', company_name: 'Acme'),
        crm_connection: create(:crm_connection, user: user, provider: 'hubspot', status: 'active'),
        payload_snapshot: { secret: 'do-not-expose' },
        request_context: { ip: '127.0.0.1', internal: true }
      )

      get crm_transfers_path, headers: inertia_headers

      expect(response).to have_http_status(:ok)

      payload = JSON.parse(response.body)
      expect(payload['component']).to eq('CrmTransfers/Index')

      transfer_payload = payload.dig('props', 'transfers').find { |item| item['id'] == transfer.id }
      expect(transfer_payload).to include(
        'id' => transfer.id,
        'provider' => 'hubspot',
        'status' => CrmTransfer::STATUS_FAILED,
        'trigger' => CrmTransfer::TRIGGER_MANUAL_EXPORT,
        'failure_kind' => CrmTransfer::FAILURE_KIND_PROVIDER_ERROR,
        'attempts_count' => 1,
        'retryable' => true
      )
      expect(transfer_payload.fetch('client')).to include(
        'id' => transfer.client_id,
        'name' => 'Jane Doe',
        'company_name' => 'Acme'
      )
      expect(transfer_payload).not_to have_key('payload_snapshot')
      expect(transfer_payload).not_to have_key('request_context')
    end

    it 'applies the default three-day window' do
      recent_transfer = create(
        :crm_transfer,
        client: create(:client, user: user),
        crm_connection: create(:crm_connection, user: user, provider: 'hubspot', status: 'active'),
        created_at: 2.days.ago
      )
      create(
        :crm_transfer,
        client: create(:client, user: user),
        crm_connection: create(:crm_connection, user: user, provider: 'salesforce', status: 'active'),
        created_at: 4.days.ago
      )

      get crm_transfers_path, headers: inertia_headers

      payload = JSON.parse(response.body)
      ids = payload.dig('props', 'transfers').map { |item| item['id'] }

      expect(ids).to contain_exactly(recent_transfer.id)
      expect(payload.dig('props', 'retention_days')).to eq(3)
    end

    it 'filters by status' do
      connection = create(:crm_connection, user: user, provider: 'hubspot', status: 'active')
      failed_transfer = create(
        :crm_transfer,
        :failed,
        client: create(:client, user: user),
        crm_connection: connection
      )
      create(
        :crm_transfer,
        :success,
        client: create(:client, user: user),
        crm_connection: connection
      )

      get crm_transfers_path(status: CrmTransfer::STATUS_FAILED), headers: inertia_headers

      payload = JSON.parse(response.body)
      ids = payload.dig('props', 'transfers').map { |item| item['id'] }

      expect(ids).to contain_exactly(failed_transfer.id)
      expect(payload.dig('props', 'filters', 'status')).to eq(CrmTransfer::STATUS_FAILED)
    end

    it 'filters by provider' do
      hubspot_transfer = create(
        :crm_transfer,
        client: create(:client, user: user),
        crm_connection: create(:crm_connection, user: user, provider: 'hubspot', status: 'active')
      )
      create(
        :crm_transfer,
        client: create(:client, user: user),
        crm_connection: create(:crm_connection, user: user, provider: 'salesforce', status: 'active')
      )

      get crm_transfers_path(provider: 'hubspot'), headers: inertia_headers

      payload = JSON.parse(response.body)
      ids = payload.dig('props', 'transfers').map { |item| item['id'] }

      expect(ids).to contain_exactly(hubspot_transfer.id)
      expect(payload.dig('props', 'filters', 'provider')).to eq('hubspot')
    end

    it 'filters by trigger' do
      connection = create(:crm_connection, user: user, provider: 'hubspot', status: 'active')
      portal_transfer = create(
        :crm_transfer,
        :portal_submit,
        client: create(:client, user: user),
        crm_connection: connection
      )
      create(
        :crm_transfer,
        :manual_export,
        client: create(:client, user: user),
        crm_connection: connection
      )

      get crm_transfers_path(trigger: CrmTransfer::TRIGGER_PORTAL_SUBMIT), headers: inertia_headers

      payload = JSON.parse(response.body)
      ids = payload.dig('props', 'transfers').map { |item| item['id'] }

      expect(ids).to contain_exactly(portal_transfer.id)
      expect(payload.dig('props', 'filters', 'trigger')).to eq(CrmTransfer::TRIGGER_PORTAL_SUBMIT)
    end

    it 'paginates results newest first' do
      connection = create(:crm_connection, user: user, provider: 'hubspot', status: 'active')
      ordered_ids = 12.times.map do |index|
        create(
          :crm_transfer,
          client: create(:client, user: user),
          crm_connection: connection,
          created_at: index.minutes.ago
        ).id
      end.reverse

      get crm_transfers_path(page: 2), headers: inertia_headers

      payload = JSON.parse(response.body)
      ids = payload.dig('props', 'transfers').map { |item| item['id'] }

      expect(payload.dig('props', 'meta')).to include(
        'page' => 2,
        'per_page' => 10,
        'total_count' => 12
      )
      expect(ids).to eq(ordered_ids.last(2))
    end
  end

  describe 'POST /crm_transfers/:id/retry' do
    it 'creates a fresh transfer row from a retryable failed transfer and enqueues it' do
      failed_transfer = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: user),
        crm_connection: create(:crm_connection, user: user, provider: 'hubspot', status: 'active'),
        request_context: {
          source: 'client_portal',
          client_form_id: 'form_123',
          ip: '127.0.0.1'
        }
      )

      expect {
        post retry_crm_transfer_path(failed_transfer), params: { status: CrmTransfer::STATUS_FAILED }, headers: auth_headers
      }.to change(CrmTransfer, :count).by(1)

      expect(response).to redirect_to(crm_transfers_path(status: CrmTransfer::STATUS_FAILED))

      retried_transfer = CrmTransfer.order(:created_at).last
      expect(retried_transfer.id).not_to eq(failed_transfer.id)
      expect(retried_transfer).to have_attributes(
        client: failed_transfer.client,
        crm_connection: failed_transfer.crm_connection,
        trigger: failed_transfer.trigger,
        status: CrmTransfer::STATUS_PENDING,
        attempts_count: 0
      )
      expect(retried_transfer.request_context).to eq(
        'source' => 'client_portal',
        'client_form_id' => 'form_123'
      )
      expect(failed_transfer.reload.status).to eq(CrmTransfer::STATUS_FAILED)
      expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }.map { |job| job[:args] }).to contain_exactly([retried_transfer.id])
    end

    it 'returns not_found when retrying a transfer owned by another user' do
      other_user = create(:user, :subscribed)
      foreign_transfer = create(
        :crm_transfer,
        :retryable_failed,
        client: create(:client, user: other_user),
        crm_connection: create(:crm_connection, user: other_user, provider: 'hubspot', status: 'active')
      )

      post retry_crm_transfer_path(foreign_transfer), headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(enqueued_jobs).to be_empty
    end

    it 'rejects transfers that are not retryable' do
      non_retryable_transfer = create(
        :crm_transfer,
        :non_retryable_failed,
        client: create(:client, user: user),
        crm_connection: create(:crm_connection, user: user, provider: 'hubspot', status: 'active')
      )

      expect {
        post retry_crm_transfer_path(non_retryable_transfer), headers: auth_headers
      }.not_to change(CrmTransfer, :count)

      expect(response).to redirect_to(crm_transfers_path)
      expect(enqueued_jobs).to be_empty
    end
  end
end