require 'rails_helper'

RSpec.describe 'Client export (GDPR)', type: :system do
  before do
    driven_by(:rack_test)
  end
  it 'allows a user to export their client data as JSON and CSV' do
    user = sign_in_user

    client = user.clients.create!(
      name: 'Acme',
      company_name: 'Acme Co',
      email: 'info@acme.test',
      phone: '+33123456789',
      address: { street: '1 Rue', city: 'Paris', postcode: '75001' }
    )

    # JSON export - visit JSON endpoint
    visit "/clients/#{client.id}/export.json"
    json = page.has_css?('pre') ? JSON.parse(page.find('pre').text) : JSON.parse(page.body)

    expect(json['name']).to eq('Acme')
    expect(json['company_name']).to eq('Acme Co')
    expect(json['email']).to eq('info@acme.test')

    # CSV export - visit CSV endpoint and verify header + values
    visit "/clients/#{client.id}/export.csv"
    expect(page.body).to include('name,company_name,company_id,country,email,phone,address,created_at,updated_at')
    expect(page.body).to include('Acme')
    expect(page.body).to include('info@acme.test')
  end
end
