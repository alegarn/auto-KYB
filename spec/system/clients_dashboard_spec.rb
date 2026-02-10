require 'rails_helper'

RSpec.describe 'Clients on Dashboard', type: :system, js: true do
  it 'lists clients on the dashboard and provides summary counts and search' do
    user = sign_in_user

    # Create a set of clients to be listed and searchable
    15.times do |i|
      user.clients.create!(name: "Client #{i + 1}", company_name: "Company #{i + 1}")
    end

    # Add a distinctive client for search
    user.clients.create!(name: 'Zeta Solutions', company_name: 'Zeta Co')

    visit '/dashboard'

    expect(page).to have_content('Clients')

    # Dashboard shows clients from the user's account
    expect(page).to have_content('Client 1')
    expect(page).to have_content('Client 15')

    # Summary count should be present
    expect(page).to have_content('Total clients')
    expect(page).to have_content(user.clients.count.to_s)

    # Search functionality (client-side filter)
    fill_in 'Search clients', with: 'Zeta'
    expect(page).to have_content('Zeta Solutions')
  end
end
