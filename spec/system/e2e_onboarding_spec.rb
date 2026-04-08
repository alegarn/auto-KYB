require 'rails_helper'

RSpec.describe 'E2E Onboarding Flow', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'allows a user to see onboarding, dismiss it, and reset it' do
    user = create(:user, email: 'onboarding-e2e@example.com', onboarding_completed: true)
    sign_in_user(user)

    visit dashboard_path

    # Verify the Onboarding Card is visible
    expect(page).to have_content('Launch your first client workflow', wait: 5)
    expect(page).to have_content('Review or create a new form')
    expect(page).to have_content('Add a client')

    # Dismiss onboarding
    page.execute_script("
      const btns = Array.from(document.querySelectorAll('button'));
      const dismissBtn = btns.find(b => b.textContent.includes('Dismiss'));
      if (dismissBtn) dismissBtn.click();
    ")
    
    # The card should disappear
    expect(page).not_to have_content('Launch your first client workflow', wait: 5)
    expect(page).not_to have_content('Review or create a new form', wait: 5)

    # Reset the onboarding
    accept_confirm do
      page.execute_script("
        const btns = Array.from(document.querySelectorAll('button'));
        const resetBtn = btns.find(b => b.textContent.includes('Reset Onboarding'));
        if (resetBtn) resetBtn.click();
      ")
    end

    # The card should be visible again
    expect(page).to have_content('Launch your first client workflow', wait: 5)
    expect(page).to have_content('Review or create a new form', wait: 5)
  end
end
