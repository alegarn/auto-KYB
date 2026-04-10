require 'rails_helper'

RSpec.describe 'Forms CRM Enumeration Mapping', type: :request do
  include ActiveJob::TestHelper

  let(:user) { sign_in_user(create(:user, :subscribed, plan: :pro)) }
  let(:session_id) { user.sessions.last.id }
  let(:headers) { { 'Cookie' => "session_token=#{session_id}" } }

  let(:form) do
    FormService.create_form(user, {
      name: 'CRM Enum Mapping Form',
      structure: { fields: [] }
    })
  end

  # HubSpot property fixtures (match plan examples)
  HS_LEAD_STATUS = {
    "name" => "hs_lead_status", "type" => "enumeration", "fieldType" => "radio",
    "options" => [
      { "label"=>"New", "value"=>"NEW", "displayOrder"=>0, "hidden"=>false },
      { "label"=>"In Progress", "value"=>"IN_PROGRESS", "displayOrder"=>2, "hidden"=>false },
      { "label"=>"Connected", "value"=>"CONNECTED", "displayOrder"=>6, "hidden"=>false }
    ], "readOnlyValue"=>false, "calculated"=>false
  }

  HS_BUYING_ROLE = {
    "name" => "hs_buying_role", "type" => "enumeration", "fieldType" => "checkbox",
    "options" => [
      { "label"=>"Blocker", "value"=>"BLOCKER", "displayOrder"=>0, "hidden"=>false },
      { "label"=>"Budget Holder", "value"=>"BUDGET_HOLDER", "displayOrder"=>1, "hidden"=>false },
      { "label"=>"Champion", "value"=>"CHAMPION", "displayOrder"=>2, "hidden"=>false }
    ], "readOnlyValue"=>false, "calculated"=>false
  }

  HS_ANALYTICS_SOURCE = {
    "name" => "hs_analytics_source", "type" => "enumeration", "fieldType" => "select",
    "options" => [
      { "label"=>"Organic Search", "value"=>"ORGANIC_SEARCH", "displayOrder"=>0, "hidden"=>false },
      { "label"=>"Paid Search", "value"=>"PAID_SEARCH", "displayOrder"=>1, "hidden"=>false },
      { "label"=>"Direct Traffic", "value"=>"DIRECT_TRAFFIC", "displayOrder"=>2, "hidden"=>false }
    ], "readOnlyValue"=>false, "calculated"=>false
  }

  describe 'POST /forms/:id/test_crm_mapping' do
    let(:connection_mock) { instance_double('Crm::Connection', provider: 'hubspot', id: 1) }
    let(:service_mock) { instance_double('Crm::HubspotService') }

    before do
      allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([ connection_mock ])
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection_mock).and_return(service_mock)
    end

    it 'US-12: exports single-choice enumeration as internal value (radio)' do
      # Provide HubSpot properties so TestPayloadBuilder uses internal values
      allow_any_instance_of(FormsController).to receive(:crm_properties).and_return({ hubspot: { contact: [ HS_LEAD_STATUS ], company: [] } })

      called_args = nil
      allow(service_mock).to receive(:export_data) do |*args|
        called_args = args
        { success: true }
      end

      test_params = {
        fields: [
          {
            label: 'Lead Status',
            field_type: 'radio',
            options: [ 'New', 'In Progress', 'Connected' ],
            metadata: {
              crm_mapping: { hubspot: { property_name: 'hs_lead_status' } }
            }
          }
        ],
        crms: [ 'hubspot' ]
      }

      post "/forms/#{form.id}/test_crm_mapping", params: test_params, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true

      # export_data receives the assembled contact hash as second arg
      expect(called_args).to be_present
      contact = called_args[1]
      expect(contact['hs_lead_status']).to eq('NEW')
    end

    it 'US-12: exports multi-select enumeration as joined internal values (checkbox)' do
      pending "Fix multi-select parsing from form structure"
      allow_any_instance_of(FormsController).to receive(:crm_properties).and_return({ hubspot: { contact: [ HS_BUYING_ROLE ], company: [] } })

      called_args = nil
      allow(service_mock).to receive(:export_data) do |*args|
        called_args = args
        { success: true }
      end

      test_params = {
        fields: [
          {
            label: 'Buying Role',
            field_type: 'checkbox',
            options: [ 'Blocker', 'Budget Holder', 'Champion' ],
            allow_multiple: true,
            metadata: {
              crm_mapping: { hubspot: { property_name: 'hs_buying_role' } }
            }
          }
        ],
        crms: [ 'hubspot' ]
      }

      post "/forms/#{form.id}/test_crm_mapping", params: test_params, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true

      expect(called_args).to be_present
      contact = called_args[1]
      expect(contact['hs_buying_role']).to eq('BLOCKER;BUDGET_HOLDER')
    end

    it 'US-13: existing select->string mapping still exports without error' do
      # Simulate a plain string HubSpot property
      hs_string = { "name" => "hs_industry", "type" => "string", "fieldType" => "text" }
      allow_any_instance_of(FormsController).to receive(:crm_properties).and_return({ hubspot: { contact: [ hs_string ], company: [] } })

      allow(service_mock).to receive(:export_data).and_return({ success: true })

      test_params = {
        fields: [
          {
            label: 'Industry',
            field_type: 'select',
            options: [],
            metadata: {
              crm_mapping: { hubspot: { property_name: 'hs_industry' } }
            }
          }
        ],
        crms: [ 'hubspot' ]
      }

      post "/forms/#{form.id}/test_crm_mapping", params: test_params, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end
  end

  describe 'PATCH /forms/:id (custom property creation)' do
    it 'US-07: enqueues CrmPropertyCreationJob for custom radio property' do
      update_params = {
        form: {
          structure: {
            fields: [
              {
                label: 'Lead Status',
                field_type: 'radio',
                options: [ 'New', 'In Progress' ],
                metadata: {
                  crm_mapping: { hubspot: { type: 'custom', object_type: 'contact' } }
                }
              }
            ]
          }
        }
      }

      expect {
        patch "/forms/#{form.id}", params: update_params, headers: headers, as: :json
      }.to have_enqueued_job(CrmPropertyCreationJob).with(user.id, array_including(hash_including(field_type: 'radio', options: [ 'New', 'In Progress' ])))

      expect(response).to have_http_status(:ok)
    end

    it 'US-09: enqueues CrmPropertyCreationJob for custom checkbox (multi-select) property' do
      update_params = {
        form: {
          structure: {
            fields: [
              {
                label: 'Buying Role',
                field_type: 'checkbox',
                allow_multiple: true,
                options: [ 'Blocker', 'Champion' ],
                metadata: {
                  crm_mapping: { hubspot: { type: 'custom' } }
                }
              }
            ]
          }
        }
      }

      expect {
        patch "/forms/#{form.id}", params: update_params, headers: headers, as: :json
      }.to have_enqueued_job(CrmPropertyCreationJob).with(user.id, array_including(hash_including(field_type: 'checkbox', options: [ 'Blocker', 'Champion' ], allow_multiple: true)))

      expect(response).to have_http_status(:ok)
    end

    it 'US-10: custom property with no options falls back to string and job creates string property' do
      pending "Fix empty properties queuing for strings"
      update_params = {
        form: {
          structure: {
            fields: [
              {
                label: 'Empty Select',
                field_type: 'select',
                options: [],
                metadata: {
                  crm_mapping: { hubspot: { type: 'custom' } }
                }
              }
            ]
          }
        }
      }

      # Prepare HubSpot client SDK mocks for the job run
      hubspot_client = instance_double('Crm::Hubspot::Client')
      sdk = double('Hubspot::SDK')
      crm = double('Hubspot::CRM')
      properties = double('Hubspot::Properties')
      core_api = double('Hubspot::CoreApi')

      allow(Crm::Hubspot::Client).to receive(:new).and_return(hubspot_client)
      allow(hubspot_client).to receive(:sdk).and_return(sdk)
      allow(sdk).to receive(:crm).and_return(crm)
      allow(crm).to receive(:properties).and_return(properties)
      allow(properties).to receive(:core_api).and_return(core_api)

      expect(core_api).to receive(:create).with(hash_including(property_create: hash_including(type: 'string', fieldType: 'text', options: [])))

      perform_enqueued_jobs do
        expect {
          patch "/forms/#{form.id}", params: update_params, headers: headers, as: :json
        }.to have_enqueued_job(CrmPropertyCreationJob).with(user.id, array_including(hash_including(options: [])))
      end

      expect(response).to have_http_status(:ok)
    end
  end
end
