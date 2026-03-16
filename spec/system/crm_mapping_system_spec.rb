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
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false },
      { 'name' => 'phone', 'label' => 'Phone', 'type' => 'string', 'read_only' => false }
    ])

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string', 'read_only' => false },
      { 'name' => 'domain', 'label' => 'Domain', 'type' => 'string', 'read_only' => false }
    ])

    visit edit_form_path(form)

    find('button', text: /CRM Sync Settings/).click

    expect(page).to have_css('[data-testid="crm-mapping-modal"]', wait: 5)

    within find('[data-testid="crm-mapping-modal"]') do
      # Click the first field's select trigger
      first_field_id = form.form_fields.first.id
      find("[data-testid=\"crm-mapping-select-#{first_field_id}-hubspot\"]").click
    end

    # Dropdown content is in modal because of portalProps disabled={true}
    within find('[data-testid="crm-mapping-modal"]') do
      expect(page).to have_selector('[data-slot="select-item"]', text: /Email/i)
      expect(page).to have_selector('[data-slot="select-item"]', text: /Company/i)
    end
  end

  it 'filters properties via the search input independently for each field' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Filter Test', structure: { 'description' => 'Test' })
    field1 = form.form_fields.create!(field_type: 'text', label: 'Field 1', position: 1, metadata: { 'crm_mapping' => {} })
    field2 = form.form_fields.create!(field_type: 'text', label: 'Field 2', position: 2, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false },
      { 'name' => 'city', 'label' => 'City', 'type' => 'string', 'read_only' => false }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    # Field 1: Search for 'City'
    find("[data-testid=\"crm-mapping-select-#{field1.id}-hubspot\"]").click
    within find('[data-testid="crm-mapping-modal"]') do
      find("input[placeholder*=\"Filter\"]").set('City')
      expect(page).to have_selector('[data-slot="select-item"]', text: /City/i)
      expect(page).not_to have_selector('[data-slot="select-item"]', text: /Email/i)
  
      # Select 'City' to close dropdown and move to field 2
      find('[data-slot="select-item"]', text: /City/i).click
    end
    expect(page).to have_no_selector('[data-slot="select-item"]')

    # Field 2: Should still show both because search is independent
    execute_script("window.scrollTo(0, document.body.scrollHeight)")
    find("[data-testid=\"crm-mapping-select-#{field2.id}-hubspot\"]").click
    within find('[data-testid="crm-mapping-modal"]') do
      expect(page).to have_selector('[data-slot="select-item"]', text: /City/i)
      expect(page).to have_selector('[data-slot="select-item"]', text: /Email/i)
  
      # Close field 2 dropdown before finishing
      find('[data-slot="select-item"]', text: /City/i).click
    end
  end

  it 'shows type mismatch warning for incompatible mappings' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Type Test', structure: { 'description' => 'Test' })
    checkbox_field = form.form_fields.create!(field_type: 'checkbox', label: 'Is Verified', position: 1, metadata: { 'crm_mapping' => {} })

    # CRM property 'verified' is a string -> incompatible with checkbox (boolean)
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'verified', 'label' => 'Verified', 'type' => 'string', 'read_only' => false }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    find("[data-testid=\"crm-mapping-select-#{checkbox_field.id}-hubspot\"]").click
    within find('[data-testid="crm-mapping-modal"]') do
      find('[data-slot="select-item"]', text: /Verified/i).click
    end

    expect(page).to have_selector("p[data-testid=\"type-mismatch-#{checkbox_field.id}-hubspot\"]", text: /Type mismatch: boolean vs string/, wait: 5)
    expect(page).to have_text('This might lead to data issues.')
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

    find("[data-testid=\"crm-mapping-select-#{checkbox_field.id}-hubspot\"]").click
    within find('[data-testid="crm-mapping-modal"]') do
      find('[data-slot="select-item"]', text: /Subscribed/i).click
    end
    
    expect(page).not_to have_selector("p[data-testid=\"type-mismatch-#{checkbox_field.id}-hubspot\"]")
  end

  it 'auto-maps fields with exact/fuzzy matches' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Auto Map', structure: { 'description' => 'Test' })
    email_field = form.form_fields.create!(field_type: 'email', label: 'Email', position: 1, metadata: { 'crm_mapping' => {} })
    company_field = form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 2, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string', 'read_only' => false }
    ])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    find('[data-testid="auto-map-fields"]').click

    # verify selects triggers show the labels
    expect(page).to have_button(text: /Email \(string\)/i)
    expect(page).to have_button(text: /Company Name \(string\)/i)
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
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string', 'read_only' => false }
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

    # use auto-map to ensure preview is ready, then send test
    find('[data-testid="auto-map-fields"]').click
    
    # Wait for summaries to be ready
    expect(page).to have_content('Contact (1 field)')
    expect(page).to have_content('Company (1 field)')

    # Use wait to ensure element is interactable
    find('button', text: /Send Test Data/, wait: 5).click

    # The UI shows a prominent success message in the modal body when done
    expect(page).to have_content('Test export sent successfully!', wait: 10)
  end

  it 'synchronizes mappings to form fields metadata upon saving' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Meta Sync', structure: { 'description' => 'Test' })
    field = form.form_fields.create!(field_type: 'text', label: 'Sync Field', position: 1, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'field_name', 'label' => 'Field Label', 'type' => 'string', 'read_only' => false }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    # Use wait and ensure we click specifically on the trigger
    find("[data-testid=\"crm-mapping-select-#{field.id}-hubspot\"]", wait: 5).click
    within find('[data-testid="crm-mapping-modal"]') do
      find('[data-slot="select-item"]', text: /Field Label/i, wait: 5).click
    end

    # Ensure dropdown is closed before clicking save
    expect(page).not_to have_selector('[data-slot="select-item"]')

    click_button 'Save Mapping'

    # Ensure modal closed
    expect(page).not_to have_css('[data-testid="crm-mapping-modal"]')

    # Verify field metadata updated
    field.reload
    expect(field.metadata['crm_mapping']['hubspot']).to eq({
      'type' => 'existing',
      'object_type' => 'contact',
      'property_name' => 'field_name',
      'read_only' => false
    })
  end
end
