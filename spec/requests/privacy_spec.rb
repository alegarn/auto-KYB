require 'rails_helper'

RSpec.describe 'Privacy', type: :request do
  it 'renders the public privacy page without authentication' do
    get privacy_path, headers: { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest }

    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Inertia']).to eq('true')

    payload = JSON.parse(response.body)
    expect(payload['component']).to eq('Privacy/Show')
    expect(payload.dig('props', 'retention_days')).to eq(3)
  end
end
