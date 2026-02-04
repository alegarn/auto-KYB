require 'rails_helper'

RSpec.describe 'Clients on Dashboard', type: :system do
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

    # Navigate to clients index
    click_link 'View all clients'
    expect(URI.parse(current_url).path).to eq('/clients')

    # Client list is displayed with name and company
    expect(page).to have_content('Client 1')
    expect(page).to have_content('Company 1')

    # Search functionality
    fill_in 'q', with: 'Zeta'
    click_button 'Search'

    expect(page).to have_content('Zeta Solutions')
    expect(page).to have_content('Zeta Co')

    # Pagination: go to page 2 and expect to see Client 11
    click_link 'Clear search'
    click_link '2'

    expect(page).to have_content('Client 11')
  end
end
