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

  def sign_in_pro_user
    sign_in_user(create(:user, :subscribed, plan: :pro, onboarding_completed: true))
  end

  def stub_hubspot_properties(contact:, company:)
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties) do |_, object_type:, force: false|
      case object_type
      when 'contact'
        contact
      when 'company'
        company
      else
        []
      end
    end
  end

  it 'renders contact and company properties fetched from CRM' do
    user = sign_in_pro_user

    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Props Form', structure: { 'description' => 'Test' })
    form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 1, metadata: { 'crm_mapping' => {} })
    form.form_fields.create!(field_type: 'email', label: 'Client Email', position: 2, metadata: { 'crm_mapping' => {} })

    stub_hubspot_properties(contact: [
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false },
      { 'name' => 'phone', 'label' => 'Phone', 'type' => 'string', 'read_only' => false }
    ], company: [
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string', 'read_only' => false },
      { 'name' => 'domain', 'label' => 'Domain', 'type' => 'string', 'read_only' => false }
    ])

    visit edit_form_path(form)

    find('button', text: /CRM Sync Settings/).click

    expect(page).to have_css('[data-testid="crm-mapping-modal"]', wait: 5)

    within find('[data-testid="crm-mapping-modal"]') do
      # Click the first field's select trigger
      first_field_id = form.form_fields.first.id
      find("[data-testid=\"crm-mapping-select-id:#{first_field_id}-hubspot\"]").click
    end

    expect(page).to have_selector('[data-slot="select-item"]', text: /Email/i)
    expect(page).to have_selector('[data-slot="select-item"]', text: /Company/i)
  end

  it 'filters properties via the search input independently for each field' do
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Filter Test', structure: { 'description' => 'Test' })
    field1 = form.form_fields.create!(field_type: 'text', label: 'Field 1', position: 1, metadata: { 'crm_mapping' => {} })
    field2 = form.form_fields.create!(field_type: 'text', label: 'Field 2', position: 2, metadata: { 'crm_mapping' => {} })

    stub_hubspot_properties(contact: [
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false },
      { 'name' => 'city', 'label' => 'City', 'type' => 'string', 'read_only' => false }
    ], company: [])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    # Field 1: Search for 'City'
    find("[data-testid=\"crm-mapping-select-id:#{field1.id}-hubspot\"]").click
    find("input[placeholder*=\"Filter\"]").set('City')
    expect(page).to have_selector('[data-slot="select-item"]', text: /City/i)
    expect(page).not_to have_selector('[data-slot="select-item"]', text: /Email/i)

    # Select 'City' to close dropdown and move to field 2
    find('[data-slot="select-item"]', text: /City/i).click
    expect(page).to have_no_selector('[data-slot="select-item"]')

    # Field 2: Should still show both because search is independent
    execute_script("window.scrollTo(0, document.body.scrollHeight)")
    field2_trigger = find("[data-testid=\"crm-mapping-select-id:#{field2.id}-hubspot\"]")
    field2_trigger.scroll_to(:center)
    field2_trigger.send_keys(:enter)
    expect(page).to have_selector('[data-slot="select-item"]', text: /City/i)
    expect(page).to have_selector('[data-slot="select-item"]', text: /Email/i)

    # Close field 2 dropdown before finishing
    find('[data-slot="select-item"]', text: /City/i).click
  end

  it 'shows type mismatch warning for incompatible mappings' do
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Type Test', structure: { 'description' => 'Test' })
    checkbox_field = form.form_fields.create!(field_type: 'checkbox', label: 'Is Verified', position: 1, metadata: { 'crm_mapping' => {} })

    # A checkbox maps to the single_choice compatibility bucket in the modal.
    # Numeric CRM properties remain incompatible and should surface a warning.
    stub_hubspot_properties(contact: [
      { 'name' => 'verified_score', 'label' => 'Verified Score', 'type' => 'number', 'read_only' => false }
    ], company: [])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    find("[data-testid=\"crm-mapping-select-id:#{checkbox_field.id}-hubspot\"]").click
    find('[data-slot="select-item"]', text: /Verified Score/i).click

    expect(page).to have_selector("p[data-testid=\"type-mismatch-#{checkbox_field.id}-hubspot\"]", text: /Type mismatch: single_choice vs number/, wait: 5)
    expect(page).to have_text('This might lead to data issues.')
  end

  it 'accepts compatible mappings (checkbox -> boolean) without warning' do
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Checkbox OK', structure: { 'description' => 'Test' })
    checkbox_field = form.form_fields.create!(field_type: 'checkbox', label: 'Subscribed', position: 1, metadata: { 'crm_mapping' => {} })

    stub_hubspot_properties(contact: [
      { 'name' => 'subscribed', 'label' => 'Subscribed', 'type' => 'enumeration', 'field_type' => 'booleancheckbox', 'read_only' => false }
    ], company: [])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    find("[data-testid=\"crm-mapping-select-id:#{checkbox_field.id}-hubspot\"]").click
    find('[data-slot="select-item"]', text: /Subscribed/i).click

    expect(page).not_to have_selector("p[data-testid=\"type-mismatch-#{checkbox_field.id}-hubspot\"]")
  end

  it 'auto-maps fields with exact/fuzzy matches' do
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Auto Map', structure: { 'description' => 'Test' })
    form.form_fields.create!(field_type: 'email', label: 'Email', position: 1, metadata: { 'crm_mapping' => {} })
    form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 2, metadata: { 'crm_mapping' => {} })

    stub_hubspot_properties(contact: [
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false }
    ], company: [
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string', 'read_only' => false }
    ])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    find('[data-testid="auto-map-fields"]').click

    # verify selects triggers show the labels
    expect(page).to have_button(text: /Email.*\(string\)/i)
    expect(page).to have_button(text: /Company Name.*\(string\)/i)
  end

  it 'applies AI auto-map suggestions, shows the AI badge, and persists the mapping after save' do
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'AI Auto Map', structure: { 'description' => 'Test' })
    legal_name_field = form.form_fields.create!(
      field_type: 'text',
      label: "What is your company's legal name?",
      position: 1,
      metadata: { 'crm_mapping' => {} }
    )

    stub_hubspot_properties(contact: [], company: [
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string', 'read_only' => false }
    ])

    mapper = instance_double(
      Crm::AiFieldMapper,
      call: Crm::AiFieldMapper::Result.new(
        suggestions: {
          legal_name_field.id.to_s => {
            object_type: 'company',
            property_name: 'name',
            confidence: 'high',
            reason: 'Semantic company-name match'
          }
        },
        unmapped_count: 0,
        error: nil
      )
    )
    allow(Crm::AiFieldMapper).to receive(:new).and_return(mapper)

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    find('[data-testid="auto-map-fields"]').click
    find('[data-testid="ai-auto-map-hubspot"]', wait: 5).click

    expect(page).to have_selector("[data-testid=\"ai-badge-id:#{legal_name_field.id}-hubspot\"]", text: /AI/, wait: 5)

    save_mapping_button = find_button('Save Mapping')
    save_mapping_button.scroll_to(:center)
    save_mapping_button.click
    expect(page).not_to have_css('[data-testid="crm-mapping-modal"]')

    click_button 'Save Changes'
    expect(page).to have_button('Save Changes', wait: 10)

    expect(legal_name_field.reload.metadata.dig('crm_mapping', 'hubspot', 'object_type')).to eq('company')
    expect(legal_name_field.metadata.dig('crm_mapping', 'hubspot', 'property_name')).to match(/(?:company::)?name/)
  end

  it 'shows an AI error while leaving standard auto-map results intact' do
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'AI Error', structure: { 'description' => 'Test' })
    email_field = form.form_fields.create!(field_type: 'email', label: 'Email', position: 1, metadata: { 'crm_mapping' => {} })
    form.form_fields.create!(field_type: 'text', label: 'Registered legal entity', position: 2, metadata: { 'crm_mapping' => {} })

    stub_hubspot_properties(contact: [
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false }
    ], company: [
      { 'name' => 'name', 'label' => 'Company Name', 'type' => 'string', 'read_only' => false }
    ])

    mapper = instance_double(
      Crm::AiFieldMapper,
      call: Crm::AiFieldMapper::Result.new(
        suggestions: {},
        unmapped_count: 1,
        error: :ai_unavailable
      )
    )
    allow(Crm::AiFieldMapper).to receive(:new).and_return(mapper)

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    find('[data-testid="auto-map-fields"]').click

    expect(page).to have_button(text: /Email.*\(string\)/i, wait: 5)

    find('[data-testid="ai-auto-map-hubspot"]', wait: 5).click

    within find('[data-provider="hubspot"]') do
      expect(page).to have_text('AI auto-map is temporarily unavailable. You can still use Auto-Map Fields or map fields manually.', wait: 5)
    end

    expect(page).to have_no_selector("[data-testid=\"ai-badge-id:#{email_field.id}-hubspot\"]")
  end

  it 'E2E: sending test data calls HubSpot endpoints to create contact, company and association' do
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Export E2E', structure: { 'description' => 'Test' })

    # Create two fields and pre-populate their hubspot export mapping so controller will build company data
    form.form_fields.create!(field_type: 'email', label: 'Email', position: 1, metadata: { 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'contact', 'property_name' => 'email' } } })
    form.form_fields.create!(field_type: 'text', label: 'Company Name', position: 2, metadata: { 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'company', 'property_name' => 'name' } } })

    # Properties so modal renders
    stub_hubspot_properties(contact: [
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false }
    ], company: [
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
    user = sign_in_pro_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Meta Sync', structure: { 'description' => 'Test' })
    field = form.form_fields.create!(field_type: 'text', label: 'Sync Field', position: 1, metadata: { 'crm_mapping' => {} })

    stub_hubspot_properties(contact: [
      { 'name' => 'field_name', 'label' => 'Field Label', 'type' => 'string', 'read_only' => false }
    ], company: [])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    # Use wait and ensure we click specifically on the trigger
    find("[data-testid=\"crm-mapping-select-id:#{field.id}-hubspot\"]", wait: 5).click
    find('[data-slot="select-item"]', text: /Field Label/i, wait: 5).click

    # Ensure dropdown is closed before clicking save
    expect(page).not_to have_selector('[data-slot="select-item"]')

    save_mapping_button = find_button('Save Mapping')
    save_mapping_button.scroll_to(:center)
    execute_script('arguments[0].click()', save_mapping_button.native)

    # Ensure modal closed
    expect(page).not_to have_css('[data-testid="crm-mapping-modal"]')

    save_changes_button = find('button', text: /Save Changes/, wait: 5)
    save_changes_button.scroll_to(:center)
    execute_script('arguments[0].click()', save_changes_button.native)
    expect(page).to have_content('Form edited', wait: 10)

    # Verify field metadata updated
    field.reload
    expect(field.metadata['crm_mapping']['hubspot']).to eq({
      'type' => 'existing',
      'object_type' => 'contact',
      'property_name' => 'contact::field_name',
      'read_only' => false
    })
  end
end
