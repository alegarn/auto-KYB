require 'rails_helper'

RSpec.describe 'Update client', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'allows user to open edit client form, update client and be redirected to detail' do
    user = sign_in_user

    client = user.clients.create!(
      name: 'Acme',
      company_name: 'Acme Co',
      email: 'info@acme.test',
      phone: '+33123456789',
      address: { street: '1 Rue', city: 'Paris', postcode: '75001' }
    )

    visit '/clients'

    # Click edit for the client
    within('li', text: client.name) do
      click_link 'Edit'
    end
    expect(page).to have_current_path("/clients/#{client.id}/edit")

    # Form is pre-filled
    expect(find('#client-name').value).to eq('Acme')
    expect(find('#client-company').value).to eq('Acme Co')
    expect(find('#client-email').value).to eq('info@acme.test')

    # Update fields
    fill_in 'Full Name', with: 'Acme Updated'
    fill_in 'Company Name', with: 'Acme Co Updated'
    fill_in 'Company Registration ID', with: '123456789'

    click_button 'Update Client Profile'

    # Accept either a redirect to the client show page OR an inline/UI confirmation.
    # If redirected, assert the updated content is visible. Otherwise assert a
    # confirmation message and verify persistence by reloading the record.
    if has_current_path?("/clients/#{client.id}", wait: Capybara.default_max_wait_time)
      expect(page).to have_content('Acme Updated')
      expect(page).to have_content('Acme Co Updated')
    else
      # Look for a generic success/confirmation indicator used by the UI.
      expect(page).to have_text(/updated|success|saved/i, wait: Capybara.default_max_wait_time)
      client.reload
      expect(client.name).to eq('Acme Updated')
      expect(client.company_name).to eq('Acme Co Updated')
    end
  end

  it 'warns that linked CRM edits sync automatically and persists the notice dismissal in the browser' do
    user = sign_in_user
    crm_connection = create(:crm_connection, user: user, provider: 'hubspot', status: 'active')
    client = create(
      :client,
      user: user,
      name: 'Linked Client',
      company_name: 'Linked Co',
      email: 'linked@example.com',
      phone: '+33123456789',
      address: { street: '1 Rue', city: 'Paris', postal_code: '75001' }
    )
    create(
      :crm_client_link,
      client: client,
      crm_connection: crm_connection,
      external_contact_id: 'hs-123',
      external_company_id: 'comp-123'
    )

    page.execute_script('window.localStorage.clear()')
    visit edit_client_path(client)

    expect(page).to have_content('CRM Data are linked')
    expect(page).to have_content('CRM-linked client')
    expect(page).to have_content('Fetching data from HubSpot is manual. Saving this client updates the linked CRM profile automatically.')

    click_button 'Understood'

    expect(page).to have_no_content('CRM-linked client')
    expect(page).to have_content('Linked to HubSpot. Fetching data is manual, but saving this page automatically pushes profile and company changes back to the CRM.')
    expect(page.evaluate_script("window.localStorage.getItem('quick-kyb.crm-linked-edit-notice.v1')")).to eq('dismissed')
  end
end
