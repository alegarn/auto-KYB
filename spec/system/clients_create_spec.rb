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

    # Submit and assert a client record was created (waits for DB change)
    expect {
      click_button 'Create client'
    }.to change { Client.where(name: 'Acme', company_name: 'Acme Co').count }.by(1)

    # If the UI redirected to a password reveal, assert that path only when present
    if page.has_text?('Password Reveal')
      expect(URI.parse(current_url).path).to match(%r{\A/client_forms/.+/password_reveal\z})
    end
  end

  it 'shows validation errors when required fields are missing' do
    sign_in_user
    visit '/clients/new'
    select 'Default KYB Form', from: 'client-form'
    click_button 'Create client'

    # Expect to see validation errors on the page (accept generic or field-specific text)
    expect(page).to have_content(/(?:Name|Company|Email)?\s?can't be blank/)
  end
end
