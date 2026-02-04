require 'rails_helper'

RSpec.describe 'Create client', type: :system do
  it 'allows user to open new client form and create a client' do
    user = sign_in_user

    visit '/clients'

    click_link 'Add client'
    expect(URI.parse(current_url).path).to eq('/clients/new')

    # Fill form
    find('input[name="client[name]"]').fill_in(with: 'Acme')
    find('input[name="client[company_name]"]').fill_in(with: 'Acme Co')
    find('input[name="client[email]"]').fill_in(with: 'info@acme.test')

    click_button 'Create client'

    # Expect redirect to clients list and to see new client
    expect(URI.parse(current_url).path).to eq('/clients')
    expect(page).to have_content('Acme')
    expect(page).to have_content('Acme Co')
  end

  it 'shows validation errors when required fields are missing' do
    sign_in_user
    visit '/clients/new'
    click_button 'Create client'

    # Expect to see validation errors on the page
    expect(page).to have_content("can't be blank").or have_content("Name can't be blank")
  end
end
