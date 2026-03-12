require 'rails_helper'
require 'webmock/rspec'

RSpec.describe 'CRM Contact Sync Workflows', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  let(:user) { create(:user, :subscribed, onboarding_completed: true) }
  let!(:crm_connection) { create(:crm_connection, user: user, provider: 'hubspot', access_token: 'fake', refresh_token: 'fake') }

  before do
    # WebMock by default blocks all net connections. We must allow localhost for Capybara's server
    WebMock.disable_net_connect!(allow_localhost: true)
    
    # We use the build-in sign_in_user helper but ensure the user state is fully prepared
    # and we wait for the redirect to complete
    sign_in_user(user)
    
    # For debugging the search failure
    # puts "Connection: #{user.crm_connections.active.count}"
    
    # Mocking CRM search endpoint (Internal API)
    stub_request(:any, /crm\/imports/).to_return(
      status: 200,
      body: [
        {
          external_contact_id: 'hs-123',
          name: 'John Doe',
          email: 'john.doe@example.com',
          company_name: 'Acme Corp'
        }
      ].to_json,
      headers: { 'Content-Type': 'application/json' }
    )

    # Mocking external HubSpot APIs (Service level)
    stub_request(:post, /api.hubapi.com.*contacts\/search/).to_return(
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

    stub_request(:get, "https://api.hubapi.com/properties/v1/contacts/properties").to_return(
      status: 200,
      body: { results: [] }.to_json,
      headers: { 'Content-Type': 'application/json' }
    )

    stub_request(:get, /api.hubapi.com.*contacts\/hs-123/).to_return(
      status: 200,
      body: {
        id: 'hs-123',
        properties: {
          firstname: 'John',
          lastname: 'Doe',
          email: 'john.doe@example.com',
          company: 'Acme Corp'
        }
      }.to_json,
      headers: { 'Content-Type': 'application/json' }
    )

    stub_request(:post, /api.hubapi.com.*contacts\/v1\/contact/).to_return(
      status: 201,
      body: {
        vid: 'hs-456'
      }.to_json,
      headers: { 'Content-Type': 'application/json' }
    )
  end

  describe 'Creating a new client' do
    it 'allows linking to an existing CRM contact' do
      visit new_client_path

      expect(page).to have_content('CRM Integration')
      
      find('label', text: 'Link existing CRM contact').click
      
      fill_in 'Search by email or name...', with: 'John'
      
      # We know the search is handled by CrmSyncWidget which does a fetch to /crm/imports
      # In system tests, we might need to trigger the search explicitly if the $effect doesn't fire
      click_button 'Search'

      # Svelte 5 result list
      expect(page).to have_content('John Doe', wait: 5)
      
      within('ul') do
        click_button 'Select'
      end

      select 'Default KYB Form', from: 'client_form[form_id]'
      fill_in 'client[name]', with: 'John Doe'
      fill_in 'client[company_name]', with: 'Acme Corp'
      fill_in 'client[email]', with: 'john.doe@example.com'

      click_button 'Create client'

      expect(page).to have_content('Client was successfully created.')
      expect(CrmClientLink.last.external_contact_id).to eq('hs-123')
    end

    it 'allows creating a new CRM contact when none exists' do
      visit new_client_path

      expect(page).to have_content('CRM Integration')
      find('label', text: 'Create new contact in CRM').click

      # Check that search is hidden
      expect(page).to have_no_selector('input[placeholder="Search by email or name..."]')

      select 'Default KYB Form', from: 'client_form[form_id]'
      fill_in 'client[name]', with: 'Jane Smith'
      fill_in 'client[company_name]', with: 'Acme Corp'
      fill_in 'client[email]', with: 'jane@example.com'

      click_button 'Create client'

      expect(page).to have_content('Password Reveal')
      # expect(new_client.crm_client_link.external_contact_id).to eq('hs-456')
    end
  end

  describe 'Editing an existing client' do
    let!(:client) { create(:client, user: user, name: 'Existing Client', email: 'existing@example.com') }
    let!(:crm_connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }

    it 'displays a match banner and allows linking' do
      # For matching, we mock an exact email search
      stub_request(:post, /api.hubapi.com.*contacts\/search/).to_return(
        status: 200,
        body: {
          results: [
            {
              id: 'hs-999',
              properties: {
                firstname: 'Existing',
                lastname: 'Client',
                email: 'existing@example.com'
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type': 'application/json' }
      )

      visit edit_client_path(client)

      # Wait for banner to appear
      expect(page).to have_content('CRM Connection Available')
      expect(page).to have_content('existing@example.com')

      click_button 'Link this contact'

      expect(page).to have_content('CRM Link Active')
      expect(client.reload.crm_client_link.external_contact_id).to eq('hs-999')
    end
  end
end
