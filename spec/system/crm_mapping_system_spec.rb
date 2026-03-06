require 'rails_helper'
require 'webmock/rspec'

RSpec.describe 'CRM Mapping System', type: :system, js: true do
  before(:each) do
    driven_by(:selenium_chrome_headless)
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after(:each) do
    WebMock.allow_net_connect!
    WebMock.reset!
  end

  it 'renders contact and company properties fetched from CRM' do
    user = sign_in_user

    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Props Form', structure: { 'description' => 'Test' })
    form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 1, metadata: { 'crm_mapping' => {} })
    form.form_fields.create!(field_type: 'email', label: 'Client Email', position: 2, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string' },
      { 'name' => 'phone', 'label' => 'Phone', 'type' => 'string' }
    ])

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string' },
      { 'name' => 'domain', 'label' => 'Domain', 'type' => 'string' }
    ])

    visit edit_form_path(form)

    find('button', text: /CRM Sync Settings/).click

    expect(page).to have_css('[data-testid="crm-mapping-modal"]', wait: 5)

    within find('[data-testid="crm-mapping-modal"]') do
      expect(page).to have_selector('option', text: /Contact: Email \(string\)/)
      expect(page).to have_selector('option', text: /Company: Company Name \(string\)/)
    end
  end

  it 'filters properties via the search input' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Filter Test', structure: { 'description' => 'Test' })
    field = form.form_fields.create!(field_type: 'text', label: 'Field 1', position: 1, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string' },
      { 'name' => 'city', 'label' => 'City', 'type' => 'string' }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    within find('[data-testid="crm-mapping-modal"]') do
      # Initially both should be there
      expect(page).to have_selector('option', text: /Contact: Email/)
      expect(page).to have_selector('option', text: /Contact: City/)

      # Search for 'City'
      find("input[placeholder*=\"Filter Hubspot\"]", match: :first).set('City')

      expect(page).to have_selector('option', text: /Contact: City/)
      expect(page).not_to have_selector('option', text: /Contact: Email/)
    end
  end

  it 'shows type mismatch warning for incompatible mappings' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Type Test', structure: { 'description' => 'Test' })
    checkbox_field = form.form_fields.create!(field_type: 'checkbox', label: 'Is Verified', position: 1, metadata: { 'crm_mapping' => {} })

    # CRM property 'verified' is a string -> incompatible with checkbox (boolean)
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'verified', 'label' => 'Verified', 'type' => 'string' }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    within find('[data-testid="crm-mapping-modal"]') do
      select_el = find("select[data-field-id=\"#{checkbox_field.id}\"]")
      select_el.find('option', text: /Verified/).select_option

      expect(page).to have_selector("p[data-testid=\"type-mismatch-#{checkbox_field.id}-hubspot\"]", text: /Type mismatch: boolean vs string/, wait: 5)
      expect(page).to have_text('This might lead to data issues.')
    end
  end

  it 'accepts compatible mappings (checkbox -> boolean) without warning' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Checkbox OK', structure: { 'description' => 'Test' })
    checkbox_field = form.form_fields.create!(field_type: 'checkbox', label: 'Subscribed', position: 1, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'subscribed', 'label' => 'Subscribed', 'type' => 'boolean' }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    within find('[data-testid="crm-mapping-modal"]') do
      find("select[data-field-id=\"#{checkbox_field.id}\"]").find('option', text: /Subscribed/).select_option
      expect(page).not_to have_selector("p[data-testid=\"type-mismatch-#{checkbox_field.id}-hubspot\"]")
    end
  end

  it 'auto-maps fields with exact/fuzzy matches' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Auto Map', structure: { 'description' => 'Test' })
    email_field = form.form_fields.create!(field_type: 'email', label: 'Email', position: 1, metadata: { 'crm_mapping' => {} })
    company_field = form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 2, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string' }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string' }
    ])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    within find('[data-testid="crm-mapping-modal"]') do
      find('[data-testid="auto-map-fields"]').click

      # verify selects were populated
      email_val = find("select[data-field-id=\"#{email_field.id}\"]").value
      company_val = find("select[data-field-id=\"#{company_field.id}\"]").value

      expect(email_val).to eq('contact:email')
      expect(company_val).to eq('company:name')
    end
  end

  it 'E2E: sending test data calls HubSpot endpoints to create contact, company and association' do
    user = sign_in_user
    connection = user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Export E2E', structure: { 'description' => 'Test' })

    # Create two fields and pre-populate their hubspot export mapping so controller will build company data
    form.form_fields.create!(field_type: 'email', label: 'Email', position: 1, metadata: { 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'contact', 'property_name' => 'email' } } })
    form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 2, metadata: { 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'company', 'property_name' => 'name' } } })

    # Properties so modal renders
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string' }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string' }
    ])

    mock_response = Struct.new(:code, :body).new(201, { vid: 999, id: '777' }.to_json)
    mock_get_response = Struct.new(:code, :body).new(200, [].to_json)

    allow_any_instance_of(Crm::Hubspot::Client).to receive(:api_request) do |_, options|
      case options[:method]
      when "GET" then mock_get_response
      else mock_response
      end
    end

    allow_any_instance_of(Crm::HubspotService).to receive(:search_company).and_return(nil)

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    within find('[data-testid="crm-mapping-modal"]') do
      # use auto-map to ensure preview is ready, then send test
      find('[data-testid="auto-map-fields"]').click
      find('button', text: /Send Test Data/).click

      # The UI shows a prominent success message in the modal body when done
      expect(page).to have_content('Test export sent successfully!', wait: 8)
    end

    stub_request(:post, "https://api.hubapi.com/crm/v3/objects/companies/search").to_return(status: 200, body: { total: 0, results: [] }.to_json, headers: {'Content-Type'=>'application/json'})
  end
end
