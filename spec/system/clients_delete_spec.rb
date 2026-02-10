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

    # Navigate to show page
    within('li', text: client.name) do
      click_link client.name
    end
    expect(URI.parse(current_url).path).to eq("/clients/#{client.id}")

    # Open confirmation dialog
    click_button 'Delete'

    # Confirm deletion in modal
    within('div[role="dialog"]') do
      click_button 'Delete'
    end

    # Expect redirected to clients list and client removed from DB
    expect(URI.parse(current_url).path).to eq('/clients')
    expect(page).not_to have_content('Acme')
    expect(Client.exists?(client.id)).to be_falsey
  end
end
