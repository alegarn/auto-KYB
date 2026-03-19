require 'rails_helper'

RSpec.describe Crm::ExportPayloadBuilder, type: :service do
  it 'builds export data from the latest client form response and includes available files' do
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

    expect(payload.data).to eq(
      'company_id' => 'REG-123',
      'Legal Name' => 'Acme Holdings'
    )
    expect(payload.files).to contain_exactly(uploaded_file)
  end
end