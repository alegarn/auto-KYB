require 'rails_helper'

RSpec.describe 'Settings - Client invite email', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  let(:user) do
    sign_in_user(
      create(
        :user,
        :subscribed,
        onboarding_completed: true,
        verified: true,
        subscription_status: 'active'
      )
    )
  end

  describe 'invite email settings card' do
    it 'is visible on the settings page' do
      user
      visit settings_path

      expect(page).to have_content('Client invite email')
      expect(page).to have_content('Configure how portal invitations are sent to clients.')
    end

    it 'shows subject and body template inputs with variable buttons' do
      user
      visit settings_path

      expect(page).to have_field('invite-subject')
      expect(page).to have_selector('textarea#invite-body')

      within '#invite-subject ~ div' do
        expect(page).to have_button('{{client_name}}')
        expect(page).to have_button('{{invite_link}}')
        expect(page).to have_button('{{password}}')
      end
    end

    it 'shows the live preview section' do
      user
      visit settings_path

      expect(page).to have_content('Preview (sample data)')
      expect(page).to have_content('Subject:')
    end

    it 'shows the Save button' do
      user
      visit settings_path

      expect(page).to have_button('Save invite email settings')
    end
  end

  describe 'toggling auto-send' do
    it 'starts with auto-send off and can be enabled' do
      user
      visit settings_path

      toggle = find('button[aria-label="Toggle automatic invite email"]')
      expect(toggle['aria-checked']).to eq('false')

      toggle.click

      expect(find('button[aria-label="Toggle automatic invite email"]')['aria-checked']).to eq('true')
    end
  end

  describe 'saving settings' do
    it 'persists a custom subject template' do
      user
      visit settings_path

      fill_in 'invite-subject', with: 'Welcome {{client_name}} to Quick KYB'
      click_button 'Save invite email settings'

      # After Inertia navigation the field should reflect the saved value
      expect(page).to have_field('invite-subject', with: 'Welcome {{client_name}} to Quick KYB')

      setting = user.reload.client_invitation_email_setting
      expect(setting).to be_present
      expect(setting.subject_template).to eq('Welcome {{client_name}} to Quick KYB')
    end

    it 'persists a custom body template using inserted variables' do
      user
      visit settings_path

      # Clear the body and type a minimal valid template
      body_area = find('textarea#invite-body')
      body_area.set('')
      body_area.set('Hi {{client_name}}, your link: {{invite_link}} pass: {{password}}')

      click_button 'Save invite email settings'

      expect(user.reload.client_invitation_email_setting.body_template).to include('{{invite_link}}')
    end

    it 'updates the live preview as the user types in the subject' do
      user
      visit settings_path

      # Default preview uses DEFAULT_SUBJECT
      expect(page).to have_css('.rounded-lg.border-dashed p', text: /Subject:/)

      fill_in 'invite-subject', with: 'Hello {{client_name}}'

      # Preview should now show the resolved name
      within '.rounded-lg.border-dashed' do
        expect(page).to have_content('Hello Jane Doe')
      end
    end

    it 'inserts a variable token into the subject field when clicking a token button' do
      user
      visit settings_path

      fill_in 'invite-subject', with: 'Access: '

      # Click the {{invite_link}} button within the subject variable strip
      # The subject variable buttons are the first set on the page
      first_variable_strip = all('div.flex.flex-wrap.gap-1').first
      within first_variable_strip do
        click_button '{{invite_link}}'
      end

      expect(page).to have_field('invite-subject', with: 'Access: {{invite_link}}')
    end
  end

  describe 'with a pre-existing setting' do
    let(:user_with_setting) do
      u = create(
        :user,
        :subscribed,
        onboarding_completed: true,
        verified: true,
        subscription_status: 'active'
      )
      u.create_client_invitation_email_setting!(
        auto_send: true,
        subject_template: 'Pre-set subject for {{client_name}}',
        body_template: 'Link: {{invite_link}} Pass: {{password}}'
      )
      sign_in_user(u)
      u
    end

    it 'pre-fills the form with saved values' do
      user_with_setting
      visit settings_path

      expect(page).to have_field('invite-subject', with: 'Pre-set subject for {{client_name}}')
      expect(page).to have_selector(
        'button[aria-label="Toggle automatic invite email"][aria-checked="true"]'
      )
    end

    it 'shows the resolved subject preview using pre-set template' do
      user_with_setting
      visit settings_path

      within '.rounded-lg.border-dashed' do
        expect(page).to have_content('Pre-set subject for Jane Doe')
      end
    end
  end
end
