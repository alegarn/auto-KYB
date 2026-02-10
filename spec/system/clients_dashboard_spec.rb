require 'rails_helper'

RSpec.describe 'Clients on Dashboard', type: :system, js: true do
  it 'shows client list on dashboard, supports search and pagination' do
    user = sign_in_user

    # Create clients for pagination and search
    15.times do |i|
      user.clients.create!(name: "Client #{i + 1}", company_name: "Company #{i + 1}")
    end

    # Add a distinctive client for search
    user.clients.create!(name: 'Zeta Solutions', company_name: 'Zeta Co')

    visit '/dashboard'

    expect(page).to have_content('Clients')

    # Client list is displayed with name and company
    expect(page).to have_content('Client 1')

    # Search functionality (client-side filter)
    fill_in 'Search clients', with: 'Zeta'
    expect(page).to have_content('Zeta Solutions')

    # Pagination: go to page 2 and expect to see older clients
    fill_in 'Search clients', with: ''
    click_button '2'
    expect(page).to have_content('Client 1')
  end
end
