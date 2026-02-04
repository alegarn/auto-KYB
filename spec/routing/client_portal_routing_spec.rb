require 'rails_helper'

RSpec.describe 'ClientPortal routes', type: :routing do
  it 'routes login with access_token to client_portal/sessions#new' do
    expect(get: '/client_portal/login/abc123').to route_to(
      controller: 'client_portal/sessions',
      action: 'new',
      access_token: 'abc123',
    )
  end

  it 'routes POST login with access_token to client_portal/sessions#create' do
    expect(post: '/client_portal/login/abc123').to route_to(
      controller: 'client_portal/sessions',
      action: 'create',
      access_token: 'abc123',
    )
  end

  it 'routes form_response show to client_portal/form_responses#show' do
    expect(get: '/client_portal/form_response').to route_to(
      controller: 'client_portal/form_responses',
      action: 'show',
    )
  end
end
