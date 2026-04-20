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

  it 'allows preserving existing CRM mappings when a user loses CRM entitlement' do
    user = sign_in_user(create(:user, :subscribed, plan: :pro))
    session_id = user.sessions.last.id
    form = FormService.create_form(user, {
      name: 'CRM Form',
      structure: {
        fields: [
          {
            label: 'Email',
            field_type: 'text',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'contact',
                  property_name: 'contact::email'
                }
              }
            }
          }
        ]
      }
    })
    field = form.form_fields.first

    user.update!(plan: :basic)

    patch "/forms/#{form.id}", params: {
      form: {
        name: 'Renamed CRM Form',
        structure: {
          fields: [
            {
              id: field.id,
              label: 'Email address',
              field_type: 'text',
              position: 1,
              metadata: {
                crm_mapping: {
                  hubspot: {
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
    }, headers: { 'Cookie' => "session_token=#{session_id}" }, as: :json

    expect(response).to have_http_status(:ok)

    form.reload
    expect(form.name).to eq('Renamed CRM Form')
    expect(form.form_fields.first.label).to eq('Email address')
    expect(form.form_fields.first.metadata.dig('crm_mapping', 'hubspot', 'property_name')).to eq('contact::email')
  end

  it 'does not enqueue CRM property creation for unchanged custom mappings after entitlement downgrade' do
    user = sign_in_user(create(:user, :subscribed, plan: :pro))
    session_id = user.sessions.last.id
    form = FormService.create_form(user, {
      name: 'Custom CRM Form',
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
    })
    field = form.form_fields.first

    user.update!(plan: :basic)

    expect do
      patch "/forms/#{form.id}", params: {
        form: {
          name: 'Custom CRM Form v2',
          structure: {
            fields: [
              {
                id: field.id,
                label: 'Department',
                field_type: 'text',
                position: 1,
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
    end.not_to have_enqueued_job(CrmPropertyCreationJob)

    expect(response).to have_http_status(:ok)
  end

  it 'allows reordering fields without treating unchanged CRM mappings as changed' do
    user = sign_in_user(create(:user, :subscribed, plan: :pro))
    session_id = user.sessions.last.id
    form = FormService.create_form(user, {
      name: 'Reorder CRM Form',
      structure: {
        fields: [
          {
            label: 'Email',
            field_type: 'text',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'contact',
                  property_name: 'contact::email'
                }
              }
            }
          }
        ]
      }
    })
    field = form.form_fields.first

    user.update!(plan: :basic)

    patch "/forms/#{form.id}", params: {
      form: {
        name: 'Reorder CRM Form',
        structure: {
          fields: [
            {
              label: 'Notes',
              field_type: 'text',
              position: 1,
              metadata: {}
            },
            {
              id: field.id,
              label: 'Email',
              field_type: 'text',
              position: 2,
              metadata: {
                crm_mapping: {
                  hubspot: {
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
    }, headers: { 'Cookie' => "session_token=#{session_id}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(form.reload.form_fields.order(:position).pluck(:label)).to eq([ 'Notes', 'Email' ])
  end

  it 'returns forbidden when a downgraded user changes a custom mapped field schema' do
    user = sign_in_user(create(:user, :subscribed, plan: :pro))
    session_id = user.sessions.last.id
    form = FormService.create_form(user, {
      name: 'Schema Change Form',
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
                  property_name: 'contact::department'
                }
              }
            }
          }
        ]
      }
    })
    field = form.form_fields.first

    user.update!(plan: :basic)

    patch "/forms/#{form.id}", params: {
      form: {
        name: 'Schema Change Form',
        structure: {
          fields: [
            {
              id: field.id,
              label: 'Department',
              field_type: 'checkbox',
              position: 1,
              metadata: {
                options: [ 'Ops', 'Finance', 'Legal' ],
                allow_multiple: true,
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
  end
end
