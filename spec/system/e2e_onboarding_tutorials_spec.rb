require 'rails_helper'

RSpec.describe 'E2E Onboarding Tutorials', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  # Helper to open the detailed onboarding sheet and switch to Explore
  def open_detailed_onboarding_and_explore
    visit dashboard_path
    click_button('Open detailed onboarding')
    click_button('Explore')
  end

  # Helper to open a guide by its visible title and start the practice CTA
  def open_guide_and_start(guide_text, cta_label)
    find('button', text: /#{Regexp.escape(guide_text)}/i).click
    expect(page).to have_selector('a, button', text: cta_label, wait: 5)
    click_on(cta_label)
  end

  # Quit the onboarding tutorial overlay and assert the query param is removed
  def quit_tutorial_and_assert_cleared
    click_button('Quit tutorial')
    expect(page).not_to have_content(/Mini tutorial \d+\/\d+/i, wait: 5)
    expect(URI.parse(current_url).query.to_s).not_to include('onboarding_tutorial')
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

  it 'runs the form export basics tutorial and shows missing-output guidance' do
    user = create(:user, :subscribed, plan: :pro, verified: true, onboarding_completed: true)
    sign_in_user(user)

    open_detailed_onboarding_and_explore

    # Open Form Builder guide and start the mapping practice
    open_guide_and_start('Form Builder', 'Practice mapping')

    # Step 1: should point at mapping tab (title visible)
    expect(page).to have_content('Open field mapping', wait: 10)

    # Advance to step 2 which is the "Review output formats" step.
    # The output-format control is intentionally absent until a preview is submitted,
    # so the tutorial should render the missing-target guidance message.
    click_button('Next')
    expect(page).to have_content('Review output formats', wait: 5)
    expect(page).to have_content('This control appears after you submit the preview once. If it is missing, switch to Preview, submit sample data, then continue.', wait: 5)

    quit_tutorial_and_assert_cleared
  end

  it 'runs the client exports tutorial and walks the JSON/CSV steps' do
    user = create(:user, :subscribed, plan: :pro, verified: true, onboarding_completed: true)
    create(:client, user: user)
    sign_in_user(user)

    open_detailed_onboarding_and_explore

    # Open Client Workflow guide and start the exports practice
    open_guide_and_start('Client Workflow', 'Practice exports')

    # The tutorial should land on the client review page with the exports inventory
    expect(page).to have_content('Find the export inventory', wait: 10)
    click_on('Jump to exports') if page.has_selector?('button, a', text: 'Jump to exports', wait: 2)
    expect(page).to have_content('Data inventory & exports', wait: 5)

    # Advance to the JSON export step and verify the tutorial action remains available
    click_button('Next')
    expect(page).to have_content('Try the JSON export', wait: 5)
    expect(page).to have_selector('button, a', text: 'Open JSON export', wait: 5)

    # Compare with the CSV export step and verify its action label
    click_button('Next')
    expect(page).to have_content('Compare with the CSV export', wait: 5)
    expect(page).to have_selector('button, a', text: 'Open CSV export', wait: 5)

    quit_tutorial_and_assert_cleared
  end

  it 'runs the crm sync tutorial with providers already connected (missing-connect branch)' do
    user = create(:user, :subscribed, plan: :pro, verified: true, onboarding_completed: true)
    # Create active connections for all known providers so the dedicated "Connect" button is absent
    %w[hubspot salesforce zoho].each do |provider|
      create(:crm_connection, user: user, provider: provider, status: 'active')
    end
    sign_in_user(user)

    open_detailed_onboarding_and_explore

    # Open the CRM guide (pro-only) and start the CRM tutorial
    open_guide_and_start('CRM Integration', 'Open CRM tutorial')

    # Step 1: integrations card exists
    expect(page).to have_content('Open the CRM integrations area', wait: 10)
    click_on('Jump to CRM integrations') if page.has_selector?('button, a', text: 'Jump to CRM integrations', wait: 2)
    expect(page).to have_content('CRM Integrations', wait: 5)

    # Step 2: connect action may be missing when providers are already connected
    click_button('Next')
    expect(page).to have_content('A dedicated Connect button is not visible because the providers may already be connected', wait: 5)

    # Step 3: auto-sync toggle should be present and can be toggled safely
    click_button('Next')
    expect(page).to have_selector('[data-onboarding-tutorial="crm-auto-sync-toggle"]', wait: 5)
    expect(page).to have_button('Toggle sync behavior', wait: 5)
    click_button('Finish tutorial')
    expect(page).not_to have_content(/Mini tutorial \d+\/\d+/i, wait: 5)
    expect(URI.parse(current_url).query.to_s).not_to include('onboarding_tutorial')
  end
end

