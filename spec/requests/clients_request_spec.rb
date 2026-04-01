require 'rails_helper'

RSpec.describe 'Clients Requests (CRM Exports)', type: :request do
  include ActiveJob::TestHelper

  let(:user) { sign_in_user(create(:user, :subscribed, plan: :pro)) }
  let(:session_id) { user.sessions.last.id }
  let(:headers) { { 'Cookie' => "session_token=#{session_id}" } }
  let(:client) { create(:client, user: user) }

  around do |example|
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe 'POST /clients/:id/export_to_crm' do
    it 'returns unauthorized when the request is unauthenticated' do
      anonymous_client = create(:client)

      post "/clients/#{anonymous_client.id}/export_to_crm", params: { crms: ['hubspot'] }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to be_blank
      expect(CrmTransfer.count).to eq(0)
    end

    it 'queues one pending transfer per selected active provider during manual client-page export' do
      hubspot_connection = create(:crm_connection, user: user, provider: 'hubspot', status: 'active')
      salesforce_connection = create(:crm_connection, user: user, provider: 'salesforce', status: 'active')
      create(:crm_connection, user: user, provider: 'zoho', status: 'active')

      expect(Crm::ConnectionManager).not_to receive(:service_for)

      expect {
        post "/clients/#{client.id}/export_to_crm", params: { crms: ['hubspot', 'salesforce'] }, headers: headers, as: :json
      }.to change { CrmTransfer.count }.by(2)

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json).to include(
        'success' => true,
        'message' => 'Manual CRM export queued. Selected CRM transfers will run in the background and may take a moment to complete.'
      )

      pending_transfers = CrmTransfer.where(status: 'pending')
      expect(pending_transfers.group(:crm_connection_id).count).to eq(
        hubspot_connection.id => 1,
        salesforce_connection.id => 1
      )

      transfers = pending_transfers.order(:created_at)
      expect(transfers.pluck(:status)).to all(eq('pending'))
      expect(transfers.pluck(:trigger)).to all(eq(CrmTransfer::TRIGGER_MANUAL_EXPORT))
      expect(transfers.pluck(:crm_connection_id)).to contain_exactly(hubspot_connection.id, salesforce_connection.id)
      expect(enqueued_jobs.count { |job| job[:job] == CrmDataExportJob }).to eq(2)
      expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }.map { |job| job[:args] }).to contain_exactly(
        [transfers.find_by!(crm_connection: hubspot_connection).id],
        [transfers.find_by!(crm_connection: salesforce_connection).id]
      )
    end

    it 'returns unprocessable_entity if no valid CRMs are selected' do
      post "/clients/#{client.id}/export_to_crm", params: { crms: [] }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('No CRM selected')
      expect(CrmTransfer.count).to eq(0)
      expect(enqueued_jobs).to be_empty
    end

    it 'returns unprocessable_entity if valid crms selected but no active connections found' do
      create(:crm_connection, user: user, provider: 'zoho', status: 'inactive')

      post "/clients/#{client.id}/export_to_crm", params: { crms: ['zoho'] }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('No active connections for selected CRMs')
      expect(CrmTransfer.count).to eq(0)
      expect(enqueued_jobs).to be_empty
    end

    it 'returns plan_insufficient for a basic user with an active subscription' do
      basic_user = sign_in_user(create(:user, :subscribed, plan: :basic))
      basic_client = create(:client, user: basic_user)
      create(:crm_connection, user: basic_user, provider: 'hubspot', status: 'active')

      post "/clients/#{basic_client.id}/export_to_crm", params: { crms: ['hubspot'] }, headers: { 'Cookie' => "session_token=#{basic_user.sessions.last.id}" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq('error' => 'plan_insufficient')
      expect(CrmTransfer.count).to eq(0)
      expect(enqueued_jobs).to be_empty
    end

    it 'returns subscription_inactive for a canceled pro user' do
      canceled_user = sign_in_user(create(:user, :canceled, plan: :pro))
      canceled_client = create(:client, user: canceled_user)
      create(:crm_connection, user: canceled_user, provider: 'hubspot', status: 'active')

      post "/clients/#{canceled_client.id}/export_to_crm", params: { crms: ['hubspot'] }, headers: { 'Cookie' => "session_token=#{canceled_user.sessions.last.id}" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq('error' => 'subscription_inactive')
      expect(CrmTransfer.count).to eq(0)
      expect(enqueued_jobs).to be_empty
    end
  end

  describe 'POST /clients/:id/create_crm_contact' do
    it 'redirects with queued wording and enqueues CrmDataExportJob' do
      create(:crm_connection, user: user, provider: 'hubspot', status: 'active')

      expect {
        post "/clients/#{client.id}/create_crm_contact", headers: headers
      }.to change(CrmTransfer, :count).by(1)

      transfer = CrmTransfer.last
      expect(transfer.status).to eq('pending')
      expect(transfer.trigger).to eq('client_create_sync')
      expect(enqueued_jobs.count { |job| job[:job] == CrmDataExportJob }).to eq(1)

      expect(response).to redirect_to(edit_client_path(client))
      follow_redirect!
      expect(response.body).to include('queued')
    end
  end
end
