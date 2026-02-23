require 'rails_helper'

RSpec.describe "Forms Update", type: :request do
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
end
