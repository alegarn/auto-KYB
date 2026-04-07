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
      metadata: { 'export_key' => 'name', 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'contact', 'property_name' => 'contact::firstname' } } })
    company_field = create(:form_field, form: form, label: 'Company Name', field_type: 'text', position: 2,
      metadata: { 'export_key' => 'name', 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'company', 'property_name' => 'company::name' } } })

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

  it 'handles legacy property_name without compound prefix via object_type fallback' do
    user = create(:user)
    client = create(:client, user: user)
    form = create(:form, user: user)
    client_form = create(:client_form, client: client, form: form)

    legacy_field = create(:form_field, form: form, label: 'Domain', field_type: 'text', position: 1,
      metadata: { 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'company', 'property_name' => 'domain' } } })

    FormResponse.create!(
      client_form: client_form,
      data: { legacy_field.id.to_s => 'acme.com' }
    )

    payload = described_class.new(client, provider: 'hubspot').build

    expect(payload.contact_data).to eq({})
    expect(payload.company_data).to eq('domain' => 'acme.com')
  end

  it 'disambiguates same CRM property name across contact and company via compound keys' do
    user = create(:user)
    client = create(:client, user: user)
    form = create(:form, user: user)
    client_form = create(:client_form, client: client, form: form)

    contact_address = create(:form_field, form: form, label: 'Personal Address', field_type: 'text', position: 1,
      metadata: { 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'contact', 'property_name' => 'contact::address' } } })
    company_address = create(:form_field, form: form, label: 'Company Address', field_type: 'text', position: 2,
      metadata: { 'crm_mapping' => { 'hubspot' => { 'type' => 'existing', 'object_type' => 'company', 'property_name' => 'company::address' } } })

    FormResponse.create!(
      client_form: client_form,
      data: {
        contact_address.id.to_s => '123 Home St',
        company_address.id.to_s => '456 Corp Blvd'
      }
    )

    payload = described_class.new(client, provider: 'hubspot').build

    expect(payload.contact_data).to eq('address' => '123 Home St')
    expect(payload.company_data).to eq('address' => '456 Corp Blvd')
  end

  context 'when client_form_id is provided' do
    let(:user) { create(:user) }
    let(:client) { create(:client, user: user) }

    it 'uses the specific form identified by client_form_id, ignoring a newer form' do
      form = create(:form, user: user)
      mapped_field = create(:form_field, form: form, label: 'Registration ID', field_type: 'text', position: 1,
        metadata: { 'export_key' => 'registration_id' })

      older_form = create(:client_form, client: client, form: form, created_at: 2.days.ago)
      FormResponse.create!(
        client_form: older_form,
        data: { mapped_field.id.to_s => 'OLD-001' }
      )

      newer_form = create(:client_form, client: client, form: form, created_at: 1.day.ago)
      FormResponse.create!(
        client_form: newer_form,
        data: { mapped_field.id.to_s => 'NEW-999' }
      )

      payload = described_class.new(client, client_form_id: older_form.id).build

      expect(payload.contact_data).to eq('registration_id' => 'OLD-001')
    end

    it 'returns an empty payload when client_form_id does not match any form owned by the client' do
      payload = described_class.new(client, client_form_id: SecureRandom.uuid).build

      expect(payload.contact_data).to eq({})
      expect(payload.company_data).to eq({})
    end
  end

  context 'latest_response selection' do
    it 'uses the most recent form response, not the oldest' do
      user = create(:user)
      client = create(:client, user: user)
      form = create(:form, user: user)
      client_form = create(:client_form, client: client, form: form)

      field = create(:form_field, form: form, label: 'Name', field_type: 'text', position: 1,
        metadata: { 'export_key' => 'name' })

      FormResponse.create!(
        client_form: client_form,
        data: { field.id.to_s => 'Old Value' },
        version: 1,
        created_at: 2.days.ago
      )
      FormResponse.create!(
        client_form: client_form,
        data: { field.id.to_s => 'Latest Value' },
        version: 2,
        created_at: 1.hour.ago
      )

      payload = described_class.new(client).build

      expect(payload.contact_data).to eq('name' => 'Latest Value')
    end
  end
end
