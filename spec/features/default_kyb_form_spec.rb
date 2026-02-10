require 'rails_helper'

RSpec.feature "Default KYB Form UI", type: :feature do
  scenario "index shows default form created by initializer" do
    sign_in_user
    visit "/forms"
    expect(page).to have_content('Default KYB Form')
  end
end
