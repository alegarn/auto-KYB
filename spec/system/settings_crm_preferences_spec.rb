require 'rails_helper'

RSpec.describe 'Settings CRM preferences', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'lets the user toggle automatic CRM sync for validated portal submissions' do
    user = sign_in_user(
      create(
        :user,
        :subscribed,
        plan: :pro,
        onboarding_completed: true,
        verified: true,
        subscription_status: 'active',
        crm_auto_sync_on_portal_submit: true
      )
    )

    visit settings_path

    expect(page).to have_content('CRM sync behavior')
    expect(page).to have_content('Validated portal submissions sync automatically.')
    expect(page).to have_selector('button[role="switch"][aria-checked="true"]')

    find('button[role="switch"]', wait: Capybara.default_max_wait_time).click

    expect(page).to have_content('Portal submissions stay local until you trigger a manual CRM update.')
    expect(page).to have_selector('button[role="switch"][aria-checked="false"]')
    expect(user.reload.crm_auto_sync_on_portal_submit).to be(false)

    find('button[role="switch"]', wait: Capybara.default_max_wait_time).click

    expect(page).to have_content('Validated portal submissions sync automatically.')
    expect(page).to have_selector('button[role="switch"][aria-checked="true"]')
    expect(user.reload.crm_auto_sync_on_portal_submit).to be(true)
  end
end