require 'rails_helper'

RSpec.describe 'Clients Requests (CRM Exports)', type: :request do
  let(:user) { sign_in_user }
  let(:session_id) { user.sessions.last.id }
  let(:headers) { { 'Cookie' => "session_token=#{session_id}" } }
  let(:client) { create(:client, user: user) }

  describe 'POST /clients/:id/export_to_crm' do
    let(:connection_mock) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }
    let(:service_mock) { instance_double('Crm::HubspotService') }

    before do
      # Note: We create a physical record so that current_user.crm_connections.where(...) finds it
      connection_mock 

      allow(Crm::ConnectionManager).to receive(:service_for).and_return(service_mock)
      allow(service_mock).to receive(:export_data).and_return({ success: true })
    end

    it 'successfully exports client data and returns status :ok' do
      post "/clients/#{client.id}/export_to_crm", params: { crms: ['hubspot'] }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(service_mock).to have_received(:export_data)
    end

    it 'exports the latest client form response payload and files' do
      form = create(:form, user: user)
      client_form = create(:client_form, client: client, form: form)
      export_field = create(:form_field, form: form, label: 'Company Registration ID', field_type: 'text', position: 1, metadata: { 'export_key' => 'company_registration_id' })
      form_response = FormResponse.create!(client_form: client_form, data: { export_field.id.to_s => 'REG-42' })
      uploaded_file = create(:uploaded_file, client: client, form_response: form_response, field_key: export_field.id.to_s)

      post "/clients/#{client.id}/export_to_crm", params: { crms: ['hubspot'] }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(service_mock).to have_received(:export_data).with(
        client,
        { 'company_registration_id' => 'REG-42' },
        [uploaded_file]
      )
    end
    
    it 'returns unprocessable_entity if no valid CRMs are selected' do
      post "/clients/#{client.id}/export_to_crm", params: { crms: [] }, headers: headers, as: :json
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('No CRM selected')
    end
    
    it 'returns unprocessable_entity if valid crms selected but no active connections found' do
      post "/clients/#{client.id}/export_to_crm", params: { crms: ['zoho'] }, headers: headers, as: :json
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('No active connections for selected CRMs')
    end
  end
end
