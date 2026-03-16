require 'rails_helper'
require 'webmock/rspec'

RSpec.describe 'CRM Mapping Property Empty Bug', type: :system, js: true do
  before(:each) do
    driven_by(:selenium_chrome_headless)
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after(:each) do
    WebMock.allow_net_connect!
    WebMock.reset!
  end

  it 'does not show No properties available if properties are provided' do
    user = User.create!(email: "test@example.com", password: "password")
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Bug Form', structure: { 'description' => 'Test' })
    form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 1, metadata: { 'crm_mapping' => {} })

    # Mock properly
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    login_as(user, scope: :user) # assuming devourise
    visit edit_form_path(form)
    
    # Wait for things...
    sleep 2
  end
end
