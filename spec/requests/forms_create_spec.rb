require 'rails_helper'

RSpec.describe "Forms Create", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "creates a form via POST and persists structure" do
    user = FactoryBot.create(:user, :subscribed)
    session_record = user.sessions.create!

    params = {
      form: {
        name: 'Customer Info',
        structure: { fields: [ { label: 'Full Name', field_type: 'text', required: true } ] }
      }
    }

    headers = { 'Cookie' => "session_token=#{session_record.id}" }

    post "/forms", params: params, headers: headers

    user.reload

    form = user.forms.find_by(name: 'Customer Info')
    expect(form).not_to be_nil
    expect(form.form_fields.count).to eq(1)
    expect(form.form_fields.first.label).to eq('Full Name')
    expect(form.structure['fields'].first['label']).to eq('Full Name')
  end

  it "returns unprocessable entity when export mapping keys are duplicated" do
    user = FactoryBot.create(:user, :subscribed)
    session_record = user.sessions.create!

    params = {
      form: {
        name: 'Customer Info',
        structure: {
          fields: [
            { label: 'Company Name', field_type: 'text', metadata: { export_key: 'company_name' } },
            { label: 'Legal Name', field_type: 'text', metadata: { export_key: 'company_name' } }
          ]
        }
      }
    }

    headers = { 'Cookie' => "session_token=#{session_record.id}" }

    post "/forms", params: params, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "normalizes custom CRM mappings on create and enqueues CRM property creation" do
    user = FactoryBot.create(:user, :subscribed, plan: :pro)
    session_record = user.sessions.create!

    params = {
      form: {
        name: 'CRM Custom Form',
        structure: {
          fields: [
            {
              label: 'Legal Name',
              field_type: 'select',
              metadata: {
                options: [ 'Option 1', 'Option 2' ],
                allow_multiple: true,
                crm_mapping: {
                  hubspot: {
                    type: 'custom',
                    object_type: 'company',
                    property_name: 'company::legal_name'
                  }
                }
              }
            }
          ]
        }
      }
    }

    headers = { 'Cookie' => "session_token=#{session_record.id}" }

    expect {
      post "/forms", params: params, headers: headers
    }.to have_enqueued_job(CrmPropertyCreationJob)

    expect(response).to have_http_status(:see_other)

    created_field = user.reload.forms.find_by(name: 'CRM Custom Form')&.form_fields&.first
    expect(created_field&.metadata&.dig('crm_mapping', 'hubspot', 'property_name')).to eq('company::legal_name')

    job = enqueued_jobs.last
    job_mapping = job[:args][1].first.deep_symbolize_keys.except(:_aj_symbol_keys)
    expect(job[:args][0]).to eq(user.id)
    expect(job_mapping).to include(
      provider: 'hubspot',
      property_name: 'legal_name',
      object_type: 'company',
      field_type: 'select',
      options: [ 'Option 1', 'Option 2' ],
      allow_multiple: true
    )
  end

  it "returns forbidden when a basic user tries to create custom CRM properties" do
    user = FactoryBot.create(:user, :subscribed, plan: :basic)
    session_record = user.sessions.create!

    params = {
      form: {
        name: 'CRM Custom Form',
        structure: {
          fields: [
            {
              label: 'Legal Name',
              field_type: 'text',
              metadata: {
                crm_mapping: {
                  hubspot: {
                    type: 'custom',
                    object_type: 'company',
                    property_name: 'company::legal_name'
                  }
                }
              }
            }
          ]
        }
      }
    }

    post "/forms", params: params, headers: { 'Cookie' => "session_token=#{session_record.id}" }, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(enqueued_jobs).to be_empty
  end
end
