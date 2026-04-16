require 'rails_helper'

RSpec.describe "Forms Update", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'updates form metadata and structure via PATCH' do
    user = sign_in_user
    session_id = user.sessions.last.id
    form = FormService.create_form(user, { name: 'Old', structure: { fields: [ { label: 'A', field_type: 'text' }, { label: 'B', field_type: 'text' } ] } })

    patch "/forms/#{form.id}", params: { form: { name: 'Updated', structure: { fields: [ { label: 'New', field_type: 'text' } ] } } }, headers: { 'Cookie' => "session_token=#{session_id}" }, as: :json

    expect(response).to have_http_status(:ok)
    form.reload
    expect(form.name).to eq('Updated')
    expect(form.form_fields.count).to eq(1)
  end

  it 'returns unprocessable entity when export mapping keys are duplicated' do
    user = sign_in_user
    session_id = user.sessions.last.id
    form = FormService.create_form(user, { name: 'Old', structure: { fields: [ { label: 'A', field_type: 'text' } ] } })

    patch "/forms/#{form.id}", params: {
      form: {
        name: 'Updated',
        structure: {
          fields: [
            { label: 'Company Name', field_type: 'text', metadata: { export_key: 'company_name' } },
            { label: 'Legal Name', field_type: 'text', metadata: { export_key: 'company_name' } }
          ]
        }
      }
    }, headers: { 'Cookie' => "session_token=#{session_id}" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'normalizes custom CRM mappings on update and enqueues CRM property creation with metadata-backed options' do
    user = sign_in_user(create(:user, :subscribed, plan: :pro))
    session_id = user.sessions.last.id
    form = FormService.create_form(user, { name: 'Old', structure: { fields: [ { label: 'A', field_type: 'text' } ] } })

    patch "/forms/#{form.id}", params: {
      form: {
        name: 'Updated',
        structure: {
          fields: [
            {
              label: 'Department',
              field_type: 'checkbox',
              metadata: {
                options: [ 'Ops', 'Finance' ],
                allow_multiple: true,
                crm_mapping: {
                  hubspot: {
                    type: 'custom',
                    object_type: 'contact',
                    property_name: 'department'
                  }
                }
              }
            }
          ]
        }
      }
    }, headers: { 'Cookie' => "session_token=#{session_id}" }, as: :json

    expect(response).to have_http_status(:ok)
    job_mapping = enqueued_jobs.last[:args][1].first.deep_symbolize_keys.except(:_aj_symbol_keys)
    expect(enqueued_jobs.last[:job]).to eq(CrmPropertyCreationJob)
    expect(job_mapping).to include(
      provider: 'hubspot',
      property_name: 'department',
      object_type: 'contact',
      field_type: 'checkbox',
      options: [ 'Ops', 'Finance' ],
      allow_multiple: true
    )

    expect(form.reload.form_fields.first.metadata.dig('crm_mapping', 'hubspot', 'property_name')).to eq('contact::department')
  end

  it 'returns forbidden when a basic user tries to create custom CRM properties on update' do
    user = sign_in_user(create(:user, :subscribed, plan: :basic))
    session_id = user.sessions.last.id
    form = FormService.create_form(user, { name: 'Old', structure: { fields: [ { label: 'A', field_type: 'text' } ] } })

    patch "/forms/#{form.id}", params: {
      form: {
        name: 'Updated',
        structure: {
          fields: [
            {
              label: 'Department',
              field_type: 'text',
              metadata: {
                crm_mapping: {
                  hubspot: {
                    type: 'custom',
                    object_type: 'contact',
                    property_name: 'contact::department'
                  }
                }
              }
            }
          ]
        }
      }
    }, headers: { 'Cookie' => "session_token=#{session_id}" }, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(enqueued_jobs).to be_empty
  end
end
