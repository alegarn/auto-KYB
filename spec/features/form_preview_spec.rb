require 'rails_helper'

RSpec.feature "Form Preview", type: :feature do
  scenario "preview renders required indicators, order, and interactions" do
    user = sign_in_user

    form = FactoryBot.create(:form, user: user)
    f1 = FactoryBot.create(:form_field, form: form, label: "Address", position: 1, required: true)
    f2 = FactoryBot.create(:form_field, form: form, label: "City", position: 2, required: false)

    visit "/forms/#{form.id}"

    expect(page).to have_content('Address')
    expect(page).to have_content('City')

    # required field indicator (asterisk) should be visible next to required label
    expect(page).to have_text('Address*')

    # fields should render in defined order
    body = page.body
    expect(body.index('Address')).to be < body.index('City')

    # interactions: fill field and submit preview (no actual form submission)
    fill_in "field_#{f1.id}", with: "123 Main St"
    click_button 'Submit Preview'

    expect(page).to have_content('Preview Results')
    expect(page).to have_content('123 Main St')
  end
end
