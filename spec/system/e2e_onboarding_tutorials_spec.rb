require 'rails_helper'

RSpec.describe 'E2E Onboarding Tutorials', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'launches client tutorial from dashboard Explore guide and quits it' do
    user = create(:user, :subscribed, plan: :pro, verified: true, onboarding_completed: true)
    sign_in_user(user)

    visit dashboard_path

    # Open the detailed onboarding sheet and switch to Explore
    click_button('Open detailed onboarding')
    click_button('Explore')

    # Open the Client Workflow guide
    find('button', text: /Client Workflow/).click

    # The practice CTA should be present and navigate to the client new page with the tutorial
    expect(page).to have_selector('a, button', text: 'Open client tutorial', wait: 5)
    click_on('Open client tutorial')

    # Overlay should appear with the expected step
    expect(page).to have_content(/Mini tutorial 1\/4/i, wait: 10)
    expect(page).to have_content('Link the form first', wait: 5)

    # Quit the tutorial and ensure the overlay is removed and query param cleared
    click_button('Quit tutorial')
    expect(page).not_to have_content(/Mini tutorial 1\/4/i, wait: 5)
    expect(URI.parse(current_url).query.to_s).not_to include('onboarding_tutorial')
  end

  it 'launches form builder tutorial, runs an action, advances a step, and quits' do
    user = create(:user, :subscribed, plan: :pro, verified: true, onboarding_completed: true)
    sign_in_user(user)

    visit dashboard_path

    # Open details and Explore
    click_button('Open detailed onboarding')
    click_button('Explore')

    # Open the Form Builder guide
    find('button', text: /Form Builder/).click

    # Start the mini tutorial (practice CTA)
    expect(page).to have_selector('a, button', text: 'Start mini tutorial', wait: 5)
    click_on('Start mini tutorial')

    # Tutorial overlay should appear on the form page
    expect(page).to have_content(/Mini tutorial 1\/4/i, wait: 10)
    expect(page).to have_content('Rename the form', wait: 5)

    # Run the focus action and verify the form name receives focus
    expect(page).to have_selector('button, a', text: 'Focus the name field', wait: 5)
    click_button('Focus the name field')
    focused = page.evaluate_script('document.activeElement && document.activeElement.id')
    expect(focused).to eq('form-name')

    # Advance one step and assert the next step title is visible
    click_button('Next')
    expect(page).to have_content('Open the field palette', wait: 5)

    # Quit the tutorial and assert it disappears and the query param is removed
    click_button('Quit tutorial')
    expect(page).not_to have_content(/Mini tutorial 1\/4/i, wait: 5)
    expect(URI.parse(current_url).query.to_s).not_to include('onboarding_tutorial')
  end
end
