require 'rails_helper'
require 'webmock/rspec'

RSpec.describe 'CRM Mapping Read Only Properties', type: :system, js: true do
  before(:each) do
    driven_by(:selenium_chrome_headless)
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after(:each) do
    WebMock.allow_net_connect!
    WebMock.reset!
  end

  it 'displays read-only properties as disabled in dropdown' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Read Only Form', structure: { 'description' => 'Test' })
    field = form.form_fields.create!(field_type: 'text', label: 'Score', position: 1, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'contact').and_return([
      { 'name' => 'score', 'label' => 'Score Value', 'type' => 'number', 'read_only' => true },
      { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false }
    ])
    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).with(object_type: 'company').and_return([])

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    # Make sure properties actually loaded (loadingProperties is false)
    expect(page).to have_css('[data-testid="crm-mapping-modal"]', wait: 5)
    expect(page).not_to have_content('Fetching CRM properties...', wait: 5)
    expect(page).not_to have_content('No properties available for hubspot.')

    # Open dropdown
    find("[data-testid=\"crm-mapping-select-#{field.id}-hubspot\"]").click

    within find('[data-testid="crm-mapping-modal"]') do
      # Should show (Read Only)
      expect(page).to have_content('Score Value (Read Only)')
      expect(page).to have_content('Email')

      # The read-only item is visually disabled / has a specific disabled attribute (depends on exactly how Radix UI/Bits UI renders it)
      # Wait... our implementation added: disabled={property.read_only} to Select.Item
      # Let's verify it has disabled or aria-disabled
      read_only_item = find('[data-slot="select-item"]', text: /Score Value/i)
      expect(read_only_item).to match_css('[data-disabled]')

      # Try clicking it, it shouldn't actually select it or close the dropdown if the UI lib prevents it.
      # However, click might just work in Selenium if it doesn't strictly adhere to pointer-events: none, so we just check the attribute.

      # Can click email
      find('[data-slot="select-item"]', text: /^Email$/i).click
    end

    # Dropdown closes
    expect(page).to have_no_selector('[data-slot="select-item"]')
  end
end
