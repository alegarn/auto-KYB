require 'rails_helper'

RSpec.describe 'View client details', type: :system do
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
    click_link client.name

    expect(URI.parse(current_url).path).to eq("/clients/#{client.id}")

    # Verify client details displayed
    expect(page).to have_content('Acme')
    expect(page).to have_content('Acme Co')
    expect(page).to have_content('info@acme.test')
    expect(page).to have_content('+33123456789')
    expect(page).to have_content('Paris').or have_content('75001')
  end
end
