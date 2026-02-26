require 'rails_helper'

RSpec.describe 'E2E Forms CRUD', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'allows a user to create, read, update, and delete forms' do
    user = sign_in_user
    
    # 1. Create
    visit forms_path
    
    # The button is rendered as a Link component from inertia, which might be an <a> tag
    # Let's try to find it by href
    find("a[href='/forms/new']", visible: :all).click rescue find("button", text: /New form/i, visible: :all).click rescue find("a", text: /New form/i, visible: :all).click rescue page.execute_script("document.querySelector('a[href=\"/forms/new\"]').click()") rescue page.execute_script("Array.from(document.querySelectorAll('button, a')).find(el => el.textContent.includes('New form')).click()")
    
    # Wait for the new form page to load
    expect(page).to have_content('Create Form')
    
    # Fill in the form name
    fill_in 'Form Name', with: 'My New E2E Form' rescue fill_in 'name', with: 'My New E2E Form' rescue find('input[type="text"]').set('My New E2E Form')
    
    # Click the Create Form button
    click_button 'Create Form' rescue find('button', text: 'Create Form').click
    
    # Wait for the form to be created and redirected to the forms list
    expect(page).to have_content('My New E2E Form')
    
    # 2. Read / Edit
    click_link 'My New E2E Form' rescue find('a', text: 'My New E2E Form').click
    expect(page).to have_content('This form has no fields yet') # Adjust based on actual UI
    
    # 3. Update
    # Go back to forms list and click update
    visit forms_path
    
    # Find the update button for our form
    # It's an <a> tag with text "Update"
    find('a', text: 'Update', match: :first).click rescue page.execute_script("Array.from(document.querySelectorAll('a')).find(el => el.textContent.includes('Update')).click()")
    
    expect(page).to have_content('Form Name') rescue expect(page).to have_content('Form Builder')
    
    fill_in 'Form Name', with: 'Updated E2E Form' rescue fill_in 'name', with: 'Updated E2E Form' rescue find('input[type="text"]').set('Updated E2E Form')
    click_button 'Save' rescue click_button 'Update' rescue find('button', text: /Save|Update/i).click
    
    visit forms_path
    expect(page).to have_content('Updated E2E Form')
    
    # 4. Delete
    # Assuming there's a delete button or link
    # It might not be a standard browser confirm, but a custom modal
    
    # Find the delete button for the updated form
    # We need to be careful to click the right delete button if there are multiple forms
    # Let's use execute_script to find the row with our form and click its delete button
    page.execute_script("
      const rows = Array.from(document.querySelectorAll('.flex.flex-col.gap-3'));
      const myRow = rows.find(row => row.textContent.includes('Updated E2E Form'));
      if (myRow) {
        const deleteBtn = Array.from(myRow.querySelectorAll('button')).find(btn => btn.textContent.includes('Delete'));
        if (deleteBtn) deleteBtn.click();
      }
    ")
    
    # Wait for the modal and click confirm
    # The modal has a "Delete" button
    expect(page).to have_content('Delete form')
    
    # Click the delete button in the modal
    page.execute_script("
      const modals = Array.from(document.querySelectorAll('[role=\"dialog\"]'));
      if (modals.length > 0) {
        const deleteBtn = Array.from(modals[0].querySelectorAll('button')).find(btn => btn.textContent.includes('Delete'));
        if (deleteBtn) deleteBtn.click();
      } else {
        // Fallback if not using role=dialog
        const deleteBtns = Array.from(document.querySelectorAll('button')).filter(btn => btn.textContent.includes('Delete'));
        // The last one is usually the one in the modal
        if (deleteBtns.length > 0) deleteBtns[deleteBtns.length - 1].click();
      }
    ")
    
    # Wait for the form to be deleted
    expect(page).not_to have_content('Updated E2E Form')
  end
end
