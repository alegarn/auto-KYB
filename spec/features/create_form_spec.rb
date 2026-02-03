require 'rails_helper'

RSpec.feature "Create Form", type: :feature do
  scenario "user creates a new form from UI" do
    user = sign_in_user

    visit "/forms"
    click_link "New Form"

    fill_in "name", with: "UI Form"
    fill_in "field_label_1", with: "Address"
    click_button "Create"

    expect(page).to have_content("UI Form")
  end
end
