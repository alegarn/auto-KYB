require 'rails_helper'

RSpec.feature "Default KYB Form in UI", type: :feature do
  scenario "a newly registered user sees the default KYB form in My Forms" do
    user = FactoryBot.create(:user, email: 'ui_user@example.com', password: 'a_secure_password_123')
    sign_in_user(user)

    visit forms_path

    expect(page).to have_content('My Forms')
    expect(page).to have_content('Default KYB Form')
  end
end
