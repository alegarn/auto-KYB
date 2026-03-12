require 'rails_helper'

RSpec.describe "CRM Synchronization during Client workflows", type: :request do
  let(:user) { create(:user, :subscribed, onboarding_completed: true) }
  # Don't use let! for client so we can test create!
  let(:client) { create(:client, user: user, email: "test@example.com") }
  let!(:connection) { create(:crm_connection, user: user, provider: "hubspot", status: "active") }
  let(:hubspot_service) { instance_double("Crm::HubspotService") }

  let(:session) { user.sessions.create! }

  before do
    cookies.signed[:session_token] = session.id
    allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(hubspot_service)
  end

  describe "POST /clients (Create Client)" do
    it "creates a new CRM contact when strategy is 'create'" do
      allow(hubspot_service).to receive(:create_contact).and_return({ id: "12345", action: :created })
      
      expect {
        post clients_path, params: {
          client: { name: "John", company_name: "Doe Inc", email: "john@example.com", internal_company_id: "123" },
          crm: { strategy: 'create' }
        }
      }.to change(Client, :count).by(1).and change(CrmClientLink, :count).by(1)

      expect(CrmClientLink.last.external_contact_id).to eq("12345")
    end

    it "links an existing contact when strategy is 'link'" do
      expect {
        post clients_path, params: {
          client: { name: "Jane", company_name: "Acme", email: "jane@example.com", internal_company_id: "124" },
          crm: { strategy: 'link', external_contact_id: "98765" }
        }
      }.to change(Client, :count).by(1).and change(CrmClientLink, :count).by(1)

      expect(CrmClientLink.last.external_contact_id).to eq("98765")
    end
  end

  describe "GET /clients/:id/crm_match_suggestions" do
    it "returns a match if found" do
      allow(hubspot_service).to receive(:search_contact_by_email).with("test@example.com").and_return({ external_contact_id: "match1" })

      get crm_match_suggestions_client_path(client)
      
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["match"]["external_contact_id"]).to eq("match1")
    end
  end

  describe "POST /clients/:id/link_crm_contact" do
    it "creates a link for the client" do
      allow(hubspot_service).to receive(:fetch_contact).with("XYZ").and_return({ name: "Jane Linked" })
      post link_crm_contact_client_path(client), params: { external_contact_id: "XYZ" }
      
      expect(client.reload.crm_client_link.external_contact_id).to eq("XYZ")
      expect(response).to redirect_to(edit_client_path(client))
    end
  end
end
