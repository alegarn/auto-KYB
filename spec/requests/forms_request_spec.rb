require 'rails_helper'

RSpec.describe 'Forms Requests (CRM Mapping)', type: :request do
  include ActiveJob::TestHelper

  let(:user) { sign_in_user }
  let(:session_id) { user.sessions.last.id }
  let(:headers) { { 'Cookie' => "session_token=#{session_id}" } }
  let(:form) do
    FormService.create_form(user, {
      name: 'CRM Mapping Test Form',
      structure: {
        fields: [
          { label: 'Company Name', field_type: 'text' }
        ]
      }
    })
  end

  describe 'PATCH /forms/:id' do
    it 'enqueues CrmPropertyCreationJob when structure includes crm_mapping' do
      update_params = {
        form: {
          structure: {
            fields: [
              {
                label: 'Expected Volume',
                field_type: 'number',
                metadata: {
                  crm_mapping: {
                    hubspot: { type: 'custom', property_name: 'expected_vol' }
                  }
                }
              }
            ]
          }
        }
      }

      expect {
        patch "/forms/#{form.id}", params: update_params, headers: headers, as: :json
      }.to have_enqueued_job(CrmPropertyCreationJob)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /forms/:id/test_crm_mapping' do
    let(:connection_mock) { instance_double('Crm::Connection', provider: 'hubspot', id: 1) }
    let(:service_mock) { instance_double('Crm::HubspotService') }

    before do
      allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([connection_mock])
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection_mock).and_return(service_mock)
      allow(service_mock).to receive(:export_data).and_return({ success: true, dummy: true })
    end

    it 'tests CRM mapping by exporting data through the mapped fields' do
      test_params = {
        fields: [
          {
            label: 'Expected Volume',
            field_type: 'number',
            metadata: {
              crm_mapping: { hubspot: { type: 'custom', property_name: 'expected_vol' } }
            }
          }
        ],
        crms: ['hubspot']
      }

      post "/forms/#{form.id}/test_crm_mapping", params: test_params, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(service_mock).to have_received(:export_data)
    end
  end
end
