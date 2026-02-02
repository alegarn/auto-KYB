require 'rails_helper'

RSpec.feature "Edit Form", type: :feature do
  scenario 'user edits a form and changes persist' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'MyForm', structure: { fields: [ { label: 'A', field_type: 'text' } ] } })

    visit "/forms/#{form.id}"
    click_link 'Edit', href: "/forms/#{form.id}/edit"

    fill_in 'Name', with: 'MyForm Updated'
    click_button 'Save'

    expect(page).to have_content('MyForm Updated')
    visit '/forms'
    expect(page).to have_content('MyForm Updated')
  end
end
