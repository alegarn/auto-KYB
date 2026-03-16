require 'rails_helper'

RSpec.describe 'CRM Spinner', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end
  it 'shows spinner' do
    user = sign_in_user
    user.crm_connections.create!(provider: 'hubspot', status: 'active', access_token: 'fake', refresh_token: 'fake')
    form = user.forms.create!(name: 'Sp Form', structure: { 'description' => 'Test' })
    visit edit_form_path(form)
    
    find('button', text: /CRM Sync Settings/).click
    
    expect(page).to have_content('Fetching CRM properties...', wait: 2)
  end
end
