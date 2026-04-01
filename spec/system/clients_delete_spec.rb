require 'rails_helper'

RSpec.describe 'Delete client', type: :system do
  it 'deletes a client after confirmation', js: true do
    user = sign_in_user

    client = user.clients.create!(
      name: 'Acme',
      company_name: 'Acme Co',
      email: 'info@acme.test',
      phone: '+33123456789',
      address: { street: '1 Rue', city: 'Paris', postcode: '75001' }
    )

    visit '/clients'

    # Navigate to show view (may be Inertia-rendered without a full URL change)
    within('li', text: client.name) do
      click_link client.name
    end
    expect(page).to have_content(client.company_name)

    # Trigger deletion
    click_button 'Delete'

    # Support either native JS confirm or in-page modal
    if page.has_selector?('div[role="dialog"]', wait: 2)
      within('div[role="dialog"]') do
        click_button 'Confirm', match: :first rescue click_button 'Delete'
      end
    end

    # Expect redirect to clients list and client removed from page and DB
    expect(page).to have_current_path('/clients', ignore_query: true)
    expect(page).not_to have_content('Acme')
    expect(Client.exists?(client.id)).to be_falsey
  end
end
