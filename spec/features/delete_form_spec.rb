require 'rails_helper'

RSpec.describe "Delete Form", type: :request do
  let(:inertia_headers) { { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest } }

  it 'deletes a form and removes it from the list' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'DeleteMe', structure: { fields: [] } })

    delete form_path(form)

    # Controller now redirects with an Inertia-scoped flash on HTML requests.
    expect(response).to have_http_status(:see_other)
    expect(Form.exists?(form.id)).to be false

    # Follow the redirect and assert the Inertia `forms/index` payload and flash.
    get response.headers['Location'], headers: inertia_headers

    # Inertia adapter may respond with 409 + X-Inertia-Location to indicate a location change
    if response.status == 409
      final_location = response.headers['X-Inertia-Location']
      get final_location, headers: inertia_headers
      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
    else
      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
    end
    names = payload.dig('props', 'forms').map { |f| f['name'] }
    expect(names).not_to include('DeleteMe')

    toast = payload.dig('props', 'flash', 'toast')
    expect(toast).to be_present
    expect(toast['message']).to eq('Form deleted')
  end
end
