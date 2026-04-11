require 'rails_helper'

RSpec.describe 'Create client', type: :system, js: true do
  it 'allows user to open new client form and create a client' do
    sign_in_user

    visit '/clients'

    click_link 'Add client'
    expect(page).to have_current_path('/clients/new')

    # Fill form
    find('#client-form').select('Default KYB Form')
    fill_in 'Full Name (Contact Person)', with: 'Acme'
    fill_in 'Registered Company Name', with: 'Acme Co'
    fill_in 'Company Registration ID', with: '123456789'
    fill_in 'Work Email', with: 'info@acme.test'

    # Store initial count
    initial_count = Client.count

    click_button 'Create Client Profile'

    # Wait for success UI
    expect(page).to have_current_path(%r{/clients/.*})

    # Verify DB insertion
    expect(Client.where(name: 'Acme', company_name: 'Acme Co').count).to eq(1)

    # If the UI redirected to invitation delivery, assert that path only when present
    if page.has_text?('Send Invitation') || page.has_text?('Password Reveal')
      expect(URI.parse(current_url).path).to match(%r{\A/client_forms/.+/(invitation_delivery|password_reveal)\z})
    end
  end

  it 'shows validation errors when required fields are missing' do
    sign_in_user
    visit '/clients/new'

    # Disable HTML5 validation to test backend validation
    page.execute_script('document.querySelector("form").setAttribute("novalidate", "novalidate")')

    find('#client-form').select('Default KYB Form')
    click_button 'Create Client Profile'

    # Expect to see validation errors on the page (accept generic or field-specific text)
    expect(page).to have_content(/(?:Name|Company|Email)?\s?can't be blank/)
  end
end
