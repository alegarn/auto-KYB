require 'rails_helper'
require 'webmock/rspec'

RSpec.describe 'CRM Spinner', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  after do
    WebMock.allow_net_connect!
  end

  it 'shows spinner' do
    user = sign_in_user
    
    WebMock.disable_net_connect!(allow_localhost: true)
    
    # Mock HubSpot API call instead of the Rails internal route.
    stub_request(:get, %r{api.hubapi.com/crm/.*}).to_return(lambda do |req|
      sleep 2
      { status: 200, body: '{"results": []}', headers: { "Content-Type" => "application/json" } }
    end)
    stub_request(:get, %r{api.hubapi.com/properties/.*}).to_return(lambda do |req|
      sleep 2
      { status: 200, body: '{"results": []}', headers: { "Content-Type" => "application/json" } }
    end)

    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')
    form = user.forms.create!(name: 'Sp Form', structure: { 'description' => 'Test' })
    visit edit_form_path(form)
    
    find('button', text: /CRM Sync Settings/).click
    
    expect(page).to have_content('Fetching CRM properties...', wait: 5)
  end
end
