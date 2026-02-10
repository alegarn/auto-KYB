require 'rails_helper'

RSpec.describe "Edit Form", type: :request do
  it 'updates a form name and persists changes' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'MyForm', structure: { fields: [ { label: 'A', field_type: 'text' } ] } })

    patch form_path(form), params: { form: { name: 'MyForm Updated' } }

    expect(response).to have_http_status(:ok)
    expect(form.reload.name).to eq('MyForm Updated')

    get forms_path, headers: { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest }
    payload = JSON.parse(response.body)
    names = payload.dig('props', 'forms').map { |f| f['name'] }
    expect(names).to include('MyForm Updated')
  end
end
