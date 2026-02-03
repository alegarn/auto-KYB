require 'rails_helper'

RSpec.describe "Forms Update", type: :request do
  it 'updates form metadata and structure via PATCH' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'Old', structure: { fields: [ { label: 'A', field_type: 'text' }, { label: 'B', field_type: 'text' } ] } })

    patch "/forms/#{form.id}", params: { form: { name: 'Updated', structure: { fields: [ { label: 'New', field_type: 'text' } ] } } }, as: :json

    expect(response).to have_http_status(:ok)
    form.reload
    expect(form.name).to eq('Updated')
    expect(form.form_fields.count).to eq(1)
  end
end
