require 'rails_helper'

RSpec.describe "Delete Form", type: :request, inertia: true do
  let(:inertia_headers) { { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest } }

  it 'deletes a form and removes it from the list' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'DeleteMe', structure: { fields: [] } })

    delete form_path(form)

    # Controller now redirects with an Inertia-scoped flash on HTML requests.
    expect(response).to have_http_status(:see_other)
    expect(Form.exists?(form.id)).to be false

    # Follow the redirect using Inertia test helper which handles 303/409 flows
    follow_redirect!

    expect(response).to have_http_status(:ok)

    # DEBUG: print props to help diagnose missing flash
    puts "INERTIA PROPS: #{inertia.props.inspect}"
    names = inertia.props.dig('forms')&.map { |f| f['name'] } || []
    expect(names).not_to include('DeleteMe')

    # flash is included in props under `flash` (may be string or symbol keys)
    toast = inertia.props.dig(:flash, 'inertia', 'toast') || inertia.props.dig('flash', 'inertia', 'toast') || inertia.props.dig(:flash, :inertia, :toast) || inertia.props.dig('flash', 'toast') || inertia.props.dig(:flash, :toast)
    expect(toast).to be_present
    expect(toast['message']).to eq('Form deleted')
  end
end
