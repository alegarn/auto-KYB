require 'rails_helper'

RSpec.feature "Delete Form", type: :feature do
  scenario 'user deletes a form and confirms removal' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'DeleteMe', structure: { fields: [] } })

    visit '/forms'
    expect(page).to have_content('DeleteMe')

    begin
      accept_confirm "Are you sure you want to delete this form?" do
        click_link 'Delete', href: "/forms/#{form.id}"
      end
    rescue Capybara::NotSupportedByDriverError
      page.driver.submit :delete, "/forms/#{form.id}", {}
    end

    expect(page).not_to have_content('DeleteMe')
    visit '/forms'
    expect(page).not_to have_content('DeleteMe')
  end
end
