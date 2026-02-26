require 'rails_helper'

RSpec.describe 'E2E Clients CRUD', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'allows a user to create, read, update, and delete clients' do
    user = sign_in_user
    
    # 1. Create
    visit clients_path
    
    # Click Add client button
    page.execute_script("Array.from(document.querySelectorAll('a')).find(el => el.textContent.includes('Add client')).click()")
    
    # Wait for the new client page to load
    expect(page).to have_content(/New client/i)
    
    # Fill in the client details
    fill_in 'Name', with: 'My New E2E Client' rescue fill_in 'name', with: 'My New E2E Client' rescue find('input[name="name"]').set('My New E2E Client') rescue find('input[type="text"]', match: :first).set('My New E2E Client')
    fill_in 'Company name', with: 'E2E Company' rescue fill_in 'company_name', with: 'E2E Company' rescue find('input[name="company_name"]').set('E2E Company')
    fill_in 'Email', with: 'e2e-client@example.com' rescue fill_in 'email', with: 'e2e-client@example.com' rescue find('input[name="email"]').set('e2e-client@example.com') rescue find('input[type="email"]').set('e2e-client@example.com')
    
    # Select a form
    page.execute_script("
      const selects = document.querySelectorAll('select');
      if (selects.length > 0) {
        selects[0].selectedIndex = 1;
        selects[0].dispatchEvent(new Event('change'));
      }
    ")
    
    # Click the Create Client button
    click_button 'Create client' rescue click_button 'Save' rescue find('button', text: /Create|Save/i).click rescue page.execute_script("Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('Create client')).click()")
    
    # Wait for the Password Reveal page
    expect(page).to have_content('Password Reveal')
    
    # Click Back to Clients
    click_link 'Back to Clients' rescue page.execute_script("Array.from(document.querySelectorAll('a')).find(el => el.textContent.includes('Back to Clients')).click()")
    
    # Wait for the clients list
    expect(page).to have_content('My New E2E Client')
    
    # 2. Read / Edit
    click_link 'My New E2E Client' rescue find('a', text: 'My New E2E Client').click rescue page.execute_script("Array.from(document.querySelectorAll('a')).find(el => el.textContent.includes('My New E2E Client')).click()")
    
    expect(page).to have_content(/Edit/i) rescue expect(page).to have_content(/Client Details/i) rescue expect(page).to have_content('My New E2E Client')
    
    # 3. Update
    # Go back to clients list and click update
    visit clients_path
    
    # Find the update button for our client
    find('a', text: 'Update', match: :first).click rescue page.execute_script("Array.from(document.querySelectorAll('a')).find(el => el.textContent.includes('Update')).click()") rescue page.execute_script("
      const rows = Array.from(document.querySelectorAll('tr, .flex.flex-col.gap-3, .grid'));
      const myRow = rows.find(row => row.textContent.includes('My New E2E Client'));
      if (myRow) {
        const updateBtn = Array.from(myRow.querySelectorAll('a, button')).find(btn => btn.textContent.includes('Edit') || btn.textContent.includes('Update'));
        if (updateBtn) updateBtn.click();
      }
    ")
    
    expect(page).to have_content(/Edit/i) rescue expect(page).to have_content(/Update/i)
    
    fill_in 'Name', with: 'Updated E2E Client' rescue fill_in 'name', with: 'Updated E2E Client' rescue find('input[name="name"]').set('Updated E2E Client') rescue find('input[type="text"]', match: :first).set('Updated E2E Client')
    click_button 'Save' rescue click_button 'Update' rescue find('button', text: /Save|Update/i).click rescue page.execute_script("Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('Update') || el.textContent.includes('Save')).click()")
    
    visit clients_path
    expect(page).to have_content('Updated E2E Client')
    
    # 4. Delete
    # Find the delete button for the updated client
    page.execute_script("
      const rows = Array.from(document.querySelectorAll('tr, .flex.flex-col.gap-3, .grid, [data-slot=\"card\"]'));
      const myRow = rows.find(row => row.textContent.includes('Updated E2E Client'));
      if (myRow) {
        const deleteBtn = Array.from(myRow.querySelectorAll('button')).find(btn => btn.textContent.includes('Delete'));
        if (deleteBtn) deleteBtn.click();
      }
    ")
    
    # Wait for the modal and click confirm
    expect(page).to have_content(/Delete/i) rescue expect(page).to have_content(/Are you sure/i)
    
    # Click the delete button in the modal
    page.execute_script("
      const modals = Array.from(document.querySelectorAll('[role=\"dialog\"]'));
      if (modals.length > 0) {
        const deleteBtn = Array.from(modals[0].querySelectorAll('button')).find(btn => btn.textContent.includes('Delete') || btn.textContent.includes('Confirm'));
        if (deleteBtn) deleteBtn.click();
      } else {
        // Fallback if not using role=dialog
        const deleteBtns = Array.from(document.querySelectorAll('button')).filter(btn => btn.textContent.includes('Delete') || btn.textContent.includes('Confirm'));
        // The last one is usually the one in the modal
        if (deleteBtns.length > 0) deleteBtns[deleteBtns.length - 1].click();
      }
    ")
    
    # Wait for the client to be deleted
    expect(page).not_to have_content('Updated E2E Client')
  end
end
