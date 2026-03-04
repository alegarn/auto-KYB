require 'rails_helper'

RSpec.describe 'CRM Contact Sync Workflows', type: :system, js: true do
  let(:user) { create(:user) }
  let!(:crm_connection) { create(:crm_connection, user: user, provider: 'hubspot', access_token: 'fake', refresh_token: 'fake') }

  before do
    login_as(user, scope: :user)
    
    # Mocking external HTTP requests for HubSpot
    stub_request(:get, /api.hubapi.com.*query=John/).to_return(
      status: 200,
      body: {
        results: [
          {
            id: 'hs-123',
            properties: {
              firstname: 'John',
              lastname: 'Doe',
              email: 'john.doe@example.com',
              company: 'Acme Corp'
            }
          }
        ]
      }.to_json,
      headers: { 'Content-Type': 'application/json' }
    )

    stub_request(:post, /api.hubapi.com.*contacts/).to_return(
      status: 201,
      body: {
        id: 'hs-456',
        properties: {
          firstname: 'Jane',
          lastname: 'Smith',
          email: 'jane@example.com'
        }
      }.to_json,
      headers: { 'Content-Type': 'application/json' }
    )
  end

  describe 'Creating a new client' do
    it 'allows linking to an existing CRM contact' do
      visit new_client_path

      expect(page).to have_content('Sync with CRM')
      
      fill_in 'Search CRM Contacts...', with: 'John'
      click_button 'Search'

      expect(page).to have_content('John Doe')
      expect(page).to have_content('john.doe@example.com')

      click_button 'Link Contact'

      # Verify form prefill (simulated by Svelte DOM updates)
      expect(page).to have_field('client[name]', with: 'John Doe')
      expect(page).to have_field('client[email]', with: 'john.doe@example.com')
      expect(page).to have_field('client[company_name]', with: 'Acme Corp')

      click_button 'Create Client'

      expect(page).to have_content('Client was successfully created.')
      expect(Client.last.crm_contacts.exists?(external_id: 'hs-123', provider: 'hubspot')).to be true
    end

    it 'allows creating a new CRM contact when none exists' do
      visit new_client_path

      fill_in 'client[name]', with: 'Jane Smith'
      fill_in 'client[email]', with: 'jane@example.com'

      choose 'Create a new contact in CRM from this client'

      click_button 'Create Client'

      expect(page).to have_content('Client was successfully created.')
      expect(Client.last.crm_contacts.exists?(external_id: 'hs-456', provider: 'hubspot')).to be true
    end
  end

  describe 'Editing an existing client' do
    let(:client) { create(:client, user: user, name: 'Existing Client', email: 'existing@example.com') }

    it 'displays a match banner and allows linking' do
      # For matching, we mock an exact email search
      stub_request(:get, /api.hubapi.com.*query=existing/).to_return(
        status: 200,
        body: {
          results: [
            { id: 'hs-999', properties: { firstname: 'Existing', lastname: 'Client', email: 'existing@example.com' } }
          ]
        }.to_json,
        headers: { 'Content-Type': 'application/json' }
      )

      visit edit_client_path(client)

      # Wait for banner to appear
      expect(page).to have_content('CRM Match Found')
      expect(page).to have_content('existing@example.com')

      click_button 'Link to Existing Client'

      expect(page).to have_content('Successfully linked 1 client')
      expect(client.reload.crm_contacts.exists?(external_id: 'hs-999')).to be true
    end
  end
end
