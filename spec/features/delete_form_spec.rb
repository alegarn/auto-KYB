require 'rails_helper'

RSpec.describe "Delete Form", type: :request do
  it 'deletes a form and removes it from the list' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'DeleteMe', structure: { fields: [] } })

    delete form_path(form)

    expect(response).to have_http_status(:ok)
    expect(Form.exists?(form.id)).to be false

    get forms_path, headers: { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest }
    payload = JSON.parse(response.body)
    names = payload.dig('props', 'forms').map { |f| f['name'] }
    expect(names).not_to include('DeleteMe')
  end
end
