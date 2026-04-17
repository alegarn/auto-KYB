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

  describe 'POST /forms/:id/validate_crm_mapping' do
    let(:connection_mock) { instance_double('Crm::Connection', provider: 'hubspot', id: 1) }
    let(:service_mock) { instance_double('Crm::HubspotService') }

    before do
      allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([ connection_mock ])
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection_mock).and_return(service_mock)
    end

    it 'returns a blocking issue when a mapped existing property no longer exists live in HubSpot' do
      allow(service_mock).to receive(:fetch_properties).with(force: true).and_return(
        contact: [
          { name: 'phone', type: 'string', read_only: false }
        ],
        company: []
      )

      post "/forms/#{form.id}/validate_crm_mapping", params: {
        fields: [
          {
            id: 'field-1',
            label: 'Phone Number',
            field_type: 'text',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'contact',
                  property_name: 'contact::phone_number'
                }
              }
            }
          }
        ]
      }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json['valid']).to be(false)
      expect(json['messages']).to include(a_string_including('HubSpot live verification found 1 blocking issue'))
      expect(json['issues']).to include(
        include(
          'provider' => 'hubspot',
          'code' => 'missing_property',
          'property_name' => 'phone_number'
        )
      )
    end

    it 'returns an option mismatch issue when the form choices do not match live HubSpot enum values' do
      allow(service_mock).to receive(:fetch_properties).with(force: true).and_return(
        contact: [],
        company: [
          {
            name: 'business_location_type',
            type: 'enumeration',
            field_type: 'select',
            read_only: false,
            options: [
              { label: 'Home Residential', value: 'home_residential' },
              { label: 'Office Business District', value: 'office_business_district' },
              { label: 'Storefront', value: 'storefront' }
            ]
          }
        ]
      )

      post "/forms/#{form.id}/validate_crm_mapping", params: {
        fields: [
          {
            id: 'field-2',
            label: 'Business Location Type',
            field_type: 'select',
            metadata: {
              options: [ 'Online', 'Storefront' ],
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'company',
                  property_name: 'company::business_location_type'
                }
              }
            }
          }
        ]
      }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      issue = json['issues'].find { |entry| entry['code'] == 'option_mismatch' }

      expect(issue).to include(
        'provider' => 'hubspot',
        'property_name' => 'business_location_type'
      )
      expect(issue['invalid_options']).to eq([ 'Online' ])
      expect(issue['allowed_options']).to include('home_residential', 'office_business_district', 'storefront')
    end

    it 'returns service unavailable when live CRM properties cannot be fetched' do
      allow(service_mock).to receive(:fetch_properties).with(force: true).and_raise(StandardError, 'timeout')

      post "/forms/#{form.id}/validate_crm_mapping", params: {
        fields: [
          {
            id: 'field-3',
            label: 'Phone Number',
            field_type: 'text',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'contact',
                  property_name: 'contact::phone'
                }
              }
            }
          }
        ]
      }, headers: headers, as: :json

      expect(response).to have_http_status(:service_unavailable)

      json = JSON.parse(response.body)
      expect(json['error']).to eq('Live CRM verification is temporarily unavailable. Please try again.')
    end
  end

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
      hubspot_connection = instance_double('Crm::Connection', provider: 'hubspot')

      allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([ hubspot_connection ])
      allow(Crm::Hubspot::Client).to receive(:new).and_return(hubspot_client)
      allow(hubspot_client).to receive(:sdk).and_return(sdk)
      allow(sdk).to receive(:crm).and_return(crm)
      allow(crm).to receive(:properties).and_return(properties)
      allow(properties).to receive(:core_api).and_return(core_api)
      allow(core_api).to receive(:create)

      expect {
        patch "/forms/#{form.id}", params: update_params, headers: headers, as: :json
      }.to have_enqueued_job(CrmPropertyCreationJob).with(user.id, array_including(hash_including(options: [])))

      job = enqueued_jobs.last
      CrmPropertyCreationJob.perform_now(
        job[:args].first,
        job[:args].second.map { |mapping| mapping.deep_symbolize_keys }
      )

      expect(core_api).to have_received(:create).with(
        hash_including(
          property_create: hash_including(type: 'string', fieldType: 'text')
        )
      )

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /forms/:id (live CRM validation)' do
    let(:connection_mock) { instance_double('Crm::Connection', provider: 'hubspot', id: 1) }
    let(:service_mock) { instance_double('Crm::HubspotService') }

    before do
      allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([ connection_mock ])
      allow(Crm::ConnectionManager).to receive(:service_for).with(connection_mock).and_return(service_mock)
    end

    it 'rejects saving a mapping to a live-missing existing HubSpot property' do
      allow(service_mock).to receive(:fetch_properties).with(force: true).and_return(
        contact: [
          { name: 'phone', type: 'string', read_only: false }
        ],
        company: []
      )

      patch "/forms/#{form.id}", params: {
        form: {
          name: form.name,
          structure: {
            fields: [
              {
                label: 'Phone Number',
                field_type: 'text',
                metadata: {
                  crm_mapping: {
                    hubspot: {
                      type: 'existing',
                      object_type: 'contact',
                      property_name: 'contact::phone_number'
                    }
                  }
                }
              }
            ]
          }
        }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json['errors']).to include(a_string_including('phone_number'))
      expect(json['errors']).to include(a_string_including('HubSpot live verification found 1 blocking issue'))
    end

    it 'returns service unavailable on save when live CRM verification cannot complete' do
      allow(service_mock).to receive(:fetch_properties).with(force: true).and_raise(StandardError, 'timeout')

      patch "/forms/#{form.id}", params: {
        form: {
          name: form.name,
          structure: {
            fields: [
              {
                label: 'Phone Number',
                field_type: 'text',
                metadata: {
                  crm_mapping: {
                    hubspot: {
                      type: 'existing',
                      object_type: 'contact',
                      property_name: 'contact::phone'
                    }
                  }
                }
              }
            ]
          }
        }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:service_unavailable)

      json = JSON.parse(response.body)
      expect(json['errors']).to include('Live CRM verification is temporarily unavailable. Please try again.')
    end

    it 'does not block mappings for providers without live property validation support' do
      salesforce_connection = instance_double('Crm::Connection', provider: 'salesforce', id: 2)
      salesforce_service = instance_double('Crm::SalesforceService')

      allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([ salesforce_connection ])
      allow(Crm::ConnectionManager).to receive(:service_for).with(salesforce_connection).and_return(salesforce_service)
      expect(salesforce_service).not_to receive(:fetch_properties)

      patch "/forms/#{form.id}", params: {
        form: {
          name: form.name,
          structure: {
            fields: [
              {
                label: 'Email',
                field_type: 'text',
                metadata: {
                  crm_mapping: {
                    salesforce: {
                      type: 'existing',
                      object_type: 'contact',
                      property_name: 'contact::email'
                    }
                  }
                }
              }
            ]
          }
        }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
