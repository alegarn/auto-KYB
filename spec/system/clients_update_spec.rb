require 'rails_helper'

RSpec.describe 'Update client', type: :system, js: true do
  it 'allows user to open edit client form, update client and be redirected to detail' do
    user = sign_in_user

    client = user.clients.create!(
      name: 'Acme',
      company_name: 'Acme Co',
      email: 'info@acme.test',
      phone: '+33123456789',
      address: { street: '1 Rue', city: 'Paris', postcode: '75001' }
    )

    visit '/clients'

    # Click edit for the client
    within('li', text: client.name) do
      click_link 'Edit'
    end
    expect(URI.parse(current_url).path).to eq("/clients/#{client.id}/edit")

    # Form is pre-filled
    expect(find('#client-name').value).to eq('Acme')
    expect(find('#client-company').value).to eq('Acme Co')
    expect(find('#client-email').value).to eq('info@acme.test')

    # Update fields
    fill_in 'client-name', with: 'Acme Updated'
    fill_in 'client-company', with: 'Acme Co Updated'

    click_button 'Update client'

    # Expect redirect to show page and updated content
    expect(URI.parse(current_url).path).to eq("/clients/#{client.id}")
    expect(page).to have_content('Acme Updated')
    expect(page).to have_content('Acme Co Updated')
  end
end
