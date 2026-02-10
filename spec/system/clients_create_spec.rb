require 'rails_helper'

RSpec.describe 'Create client', type: :system, js: true do
  it 'allows user to open new client form and create a client' do
    sign_in_user

    visit '/clients'

    click_link 'Add client'
    expect(URI.parse(current_url).path).to eq('/clients/new')

    # Fill form
    select 'Default KYB Form', from: 'client-form'
    fill_in 'client-name', with: 'Acme'
    fill_in 'client-company', with: 'Acme Co'
    fill_in 'client-email', with: 'info@acme.test'

    click_button 'Create client'

    # Expect redirect to password reveal for newly linked form
    expect(URI.parse(current_url).path).to match(%r{\A/client_forms/.+/password_reveal\z})
    expect(page).to have_content('Password Reveal')
    expect(Client.where(name: 'Acme', company_name: 'Acme Co')).to exist
  end

  it 'shows validation errors when required fields are missing' do
    sign_in_user
    visit '/clients/new'
    select 'Default KYB Form', from: 'client-form'
    click_button 'Create client'

    # Expect to see validation errors on the page
    expect(page).to have_content("can't be blank").or have_content("Name can't be blank")
  end
end
