require 'rails_helper'

RSpec.describe "Create Form", type: :request do
  it "creates a new form via request" do
    user = sign_in_user

    expect {
      post forms_path,
           params: { form: { name: "UI Form", structure: { fields: [] } } },
           headers: { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest, 'Accept' => 'application/json' }
    }.to change { user.forms.count }.by(1)

    expect(response).to have_http_status(:see_other)

    get forms_path, headers: { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest, 'Accept' => 'application/json' }
    payload = JSON.parse(response.body)
    names = payload.dig('props', 'forms').map { |form| form['name'] }
    expect(names).to include("UI Form")
  end
end
