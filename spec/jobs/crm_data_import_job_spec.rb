require 'rails_helper'

RSpec.describe CrmDataImportJob, type: :job do
  let(:user) { create(:user) }
  let(:connection) { create(:crm_connection, user: user) }
  let(:service) { instance_double("Crm::HubspotService") }

  before do
    allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(service)
  end

  describe '#perform' do
    let(:contact_data) do
      {
        hubspot_id: "123",
        email: "new@example.com",
        name: "New Contact",
        phone: "555-1234",
        company_name: "New Corp",
        address: "123 New St"
      }
    end

    let(:page) do
      {
        results: [ contact_data ],
        paging: { next: { after: "next_cursor" } }
      }
    end

    it 'imports contacts and enqueues next page' do
      expect(service).to receive(:fetch_contacts).with(limit: 100, after: nil).and_return(page)

      expect {
        described_class.perform_now(connection.id)
      }.to change(Client, :count).by(1)
       .and change(CrmTransfer, :count).by(1)

      client = Client.last
      expect(client.email).to eq("new@example.com")
      expect(client.name).to eq("New Contact")
      expect(client.company_name).to eq("New Corp")

      transfer = CrmTransfer.last
      expect(transfer.client).to eq(client)
      expect(transfer.crm_connection).to eq(connection)
      expect(transfer.direction).to eq("import")
      expect(transfer.external_id).to eq("123")
      expect(transfer.external_type).to eq("contact")
      expect(transfer.status).to eq("success")

      expect(described_class).to have_been_enqueued.with(connection.id, { "after" => "next_cursor" })
    end

    it 'updates an existing contact' do
      existing_client = create(:client, user: user, email: "new@example.com", name: "Old Name")

      expect(service).to receive(:fetch_contacts).with(limit: 100, after: nil).and_return({ results: [ contact_data ], paging: nil })

      expect {
        described_class.perform_now(connection.id)
      }.to change(Client, :count).by(0)
       .and change(CrmTransfer, :count).by(1)

      expect(existing_client.reload.name).to eq("New Contact")
    end

    it 'does not create transfer if no changes were made' do
      create(:client, user: user,
        email: "new@example.com",
        name: "New Contact",
        company_name: "New Corp",
        phone: "555-1234",
        address: "123 New St"
      )

      expect(service).to receive(:fetch_contacts).with(limit: 100, after: nil).and_return({ results: [ contact_data ], paging: nil })

      expect {
        described_class.perform_now(connection.id)
      }.to change(Client, :count).by(0).and change(CrmTransfer, :count).by(0)
    end
  end
end
