require 'rails_helper'

RSpec.describe 'CRM Company Creation Notice', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  let(:user) { create(:user, :subscribed, onboarding_completed: true) }

  before do
    sign_in_user(user)
    user.crm_connections.create!(provider: "hubspot", status: "active", access_token: "fake", refresh_token: "fake")
  end

  it 'shows the notice when CRM strategy is create and company info is completed' do
    visit '/clients/new'
    find('label', text: 'Create new contact in CRM').click

    expect(page).not_to have_text('New CRM Company Record')

    fill_in 'Registered Company Name', with: 'Acme Corp'
    fill_in 'Company Registration ID', with: 'REG-123'

    expect(page).to have_text('New CRM Company Record')
    expect(page).to have_text('This will create a new company record in your CRM')
  end

  it 'hides the notice if company name is cleared' do
    visit '/clients/new'
    find('label', text: 'Create new contact in CRM').click
    fill_in 'Registered Company Name', with: 'Acme Corp'
    fill_in 'Company Registration ID', with: 'REG-123'
    expect(page).to have_text('New CRM Company Record')

    fill_in 'Registered Company Name', with: ''
    expect(page).not_to have_text('New CRM Company Record')
  end

  it 'hides the notice if strategy is changed to skip' do
    visit '/clients/new'
    fill_in 'Registered Company Name', with: 'Acme Corp'
    fill_in 'Company Registration ID', with: 'REG-123'
    find('label', text: 'Create new contact in CRM').click
    expect(page).to have_text('New CRM Company Record')

    find('label', text: 'Do not sync with CRM yet').click
    expect(page).not_to have_text('New CRM Company Record')
  end

  it 'correctly prefills fields and shows notice when CRM contact is linked' do
    visit '/clients/new'
    find('label', text: 'Create new contact in CRM').click
    fill_in 'Registered Company Name', with: 'Initech'
    fill_in 'Company Registration ID', with: '999'
    expect(page).to have_text('New CRM Company Record')
  end
end
