require 'rails_helper'

RSpec.describe 'CRM Mapping System', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'allows user to map form fields to CRM properties dynamically' do
    user = sign_in_user
    
    user.crm_connections.create!(
      provider: 'hubspot',
      status: 'active',
      access_token: 'fake',
      refresh_token: 'fake'
    )
    
    form = user.forms.create!(
      name: 'Test Setup Form',
      structure: { "description" => "Test form" }
    )
    
    company_ff = form.form_fields.create!(
      field_type: "text",
      label: "Company Name",
      required: true,
      position: 1,
      metadata: { "placeholder" => "Enter company name", "crm_mapping" => {} }
    )
    
    email_ff = form.form_fields.create!(
      field_type: "email",
      label: "Client Email",
      required: true,
      position: 2,
      metadata: { "placeholder" => "Enter email", "crm_mapping" => {} }
    )

    allow_any_instance_of(Crm::Hubspot::PropertiesService).to receive(:list_properties).and_return([
      { name: "company", label: "Company Name", type: "string" },
      { name: "email", label: "Email", type: "string" }
    ])
    
    visit edit_form_path(form)

    expect(page).to have_content('Company Name')
    expect(page).to have_content('Client Email')
    
    find('button', text: 'CRM Sync Settings').click
    
    expect(page).to have_content('CRM Field Mapping')
    expect(page).to have_content('Hubspot')
    
    within find('tr', text: 'Company Name', match: :first) do
      find('select').select('Company Name')
    end

    within find('tr', text: 'Client Email', match: :first) do
      find('select').select('+ Create as Custom Property')
    end

    click_button 'Save Mapping'
    
    expect(page).not_to have_content('CRM Field Mapping', wait: 2)
    
    click_button 'Save Changes'
    
    sleep 1
    
    form.reload
    company_field = form.form_fields.find(company_ff.id)
    email_field = form.form_fields.find(email_ff.id)
    
    expect(company_field.metadata["crm_mapping"]).to be_an(Hash)
    expect(company_field.metadata.dig("crm_mapping", "hubspot")).to include(
      "type" => "existing",
      "property_name" => "company"
    )

    expect(email_field.metadata["crm_mapping"]).to be_an(Hash)
    expect(email_field.metadata.dig("crm_mapping", "hubspot")).to include(
      "type" => "custom",
      "property_name" => "client_email"
    )
  end
end
