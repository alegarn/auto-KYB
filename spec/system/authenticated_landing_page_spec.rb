require 'rails_helper'

RSpec.describe 'Authenticated landing page', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
    page.current_window.resize_to(1280, 1600)
  end

  it 'shows authenticated actions on the landing page and allows logout' do
    user = create(:user, :subscribed, onboarding_completed: true)

    sign_in_user(user)

    visit root_path

    expect(page).to have_content('Quick KYB')
    expect(page).to have_link('Start Onboarding', wait: 15)
    expect(page).to have_button('Request a demo', wait: 15)
    expect(page).to have_no_link('Dashboard')

    click_link 'Start Onboarding', match: :first
    expect(page).to have_current_path(dashboard_path, ignore_query: true, wait: 15)

    visit root_path
    execute_script('window.scrollTo(0, 200)')

    expect(page).to have_link('Dashboard', wait: 15)
    expect(page).to have_button('Logout', wait: 15)

    click_button 'Logout', match: :first

    expect(page).to have_current_path(sign_in_path, ignore_query: true, wait: 15)
    expect(page).to have_content('Sign In to Quick KYB')
    expect(page).to have_button('Email me a sign-in link')
  end
end