require 'rails_helper'

RSpec.describe Crm::ExportPayloadBuilder, type: :service do
  it 'builds contact and company data from the latest client form response' do
    user = create(:user)
    client = create(:client, user: user)
    form = create(:form, user: user)
    client_form = create(:client_form, client: client, form: form)
    mapped_field = create(:form_field, form: form, label: 'Company ID', field_type: 'text', position: 1, metadata: { 'export_key' => 'company_id' })
    fallback_field = create(:form_field, form: form, label: 'Legal Name', field_type: 'text', position: 2)
    create(:form_field, form: form, label: 'Section title', field_type: 'section', position: 3)
    response = FormResponse.create!(
      client_form: client_form,
      data: {
        mapped_field.id.to_s => 'REG-123',
        fallback_field.id.to_s => 'Acme Holdings'
      }
    )
    uploaded_file = create(:uploaded_file, client: client, form_response: response, field_key: mapped_field.id.to_s)

    payload = described_class.new(client).build

    expect(payload.contact_data).to eq(
      'company_id' => 'REG-123',
      'Legal Name' => 'Acme Holdings'
    )
    expect(payload.company_data).to eq({})
    expect(payload.files).to contain_exactly(uploaded_file)
  end

  it 'splits data by object_type when provider is specified' do
    user = create(:user)
    client = create(:client, user: user)
    form = create(:form, user: user)
    client_form = create(:client_form, client: client, form: form)

    contact_field = create(:form_field, form: form, label: 'Contact Name', field_type: 'text', position: 1,
      metadata: { 'export_key' => 'name', 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'contact', 'property_name' => 'firstname' } } })
    company_field = create(:form_field, form: form, label: 'Company Name', field_type: 'text', position: 2,
      metadata: { 'export_key' => 'name', 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'company', 'property_name' => 'name' } } })

    FormResponse.create!(
      client_form: client_form,
      data: {
        contact_field.id.to_s => 'John Doe',
        company_field.id.to_s => 'Acme Corp'
      }
    )

    payload = described_class.new(client, provider: 'hubspot').build

    expect(payload.contact_data).to eq('firstname' => 'John Doe')
    expect(payload.company_data).to eq('name' => 'Acme Corp')
  end
end