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
    user = sign_in_user(create(:user, :subscribed, plan: :pro, onboarding_completed: true))
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')

    form = user.forms.create!(name: 'Read Only Form', structure: { 'description' => 'Test' })
    field = form.form_fields.create!(field_type: 'text', label: 'Score', position: 1, metadata: { 'crm_mapping' => {} })

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties) do |_, object_type:, force: false|
      case object_type
      when 'contact'
        [
          { 'name' => 'score', 'label' => 'Score Value', 'type' => 'number', 'read_only' => true },
          { 'name' => 'email', 'label' => 'Email', 'type' => 'string', 'read_only' => false }
        ]
      when 'company'
        []
      else
        []
      end
    end

    visit edit_form_path(form)
    find('button', text: /CRM Sync Settings/).click

    # Make sure properties actually loaded (loadingProperties is false)
    expect(page).to have_css('[data-testid="crm-mapping-modal"]', wait: 5)
    expect(page).not_to have_content('Fetching CRM properties...', wait: 5)
    expect(page).not_to have_content('No properties available for hubspot.')

    # Open dropdown
    field_trigger = find("[data-testid=\"crm-mapping-select-id:#{field.id}-hubspot\"]", wait: 5)
    field_trigger.scroll_to(:center)
    field_trigger.send_keys(:enter)
    expect(page).to have_selector('[data-slot="select-item"]', wait: 5)

    expect(page).to have_selector('[data-slot="select-item"]', text: /^Email \[Contact\]/i)

    read_only_item = find('[data-slot="select-item"]', text: /Score Value.*Read Only/i)
    expect(read_only_item).to match_css('[data-disabled]')

    find('[data-slot="select-item"]', text: /^Email \[Contact\]/i).click

    # Dropdown closes
    expect(page).to have_no_selector('[data-slot="select-item"]')
  end
end
