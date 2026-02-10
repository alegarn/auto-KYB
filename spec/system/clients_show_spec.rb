require 'rails_helper'

RSpec.describe 'View client details', type: :system, js: true do
  it 'navigates to client detail page and shows client info' do
    user = sign_in_user

    client = user.clients.create!(
      name: 'Acme',
      company_name: 'Acme Co',
      email: 'info@acme.test',
      phone: '+33123456789',
      address: { street: '1 Rue', city: 'Paris', postcode: '75001' }
    )

    visit '/clients'

    # Click the client link to go to show page
    within('li', text: client.name) do
      click_link client.name
    end

    expect(URI.parse(current_url).path).to eq("/clients/#{client.id}")

    # Wait for Inertia navigation to finish: either the page heading
    # or the component content (client name) should appear.
    expect(page).to have_content('Client details').or have_content(client.name)

    # Verify client details displayed
    expect(page).to have_content(client.name)
    expect(page).to have_content(client.company_name)
    expect(page).to have_content(client.email)
    expect(page).to have_content(client.phone)
    expect(page).to have_content('Paris').or have_content('75001')
  end
end
