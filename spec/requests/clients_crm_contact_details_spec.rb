require "rails_helper"

RSpec.describe "GET /clients/:id/crm_contact_details", type: :request do
  let(:user) { create(:user, :subscribed) }
  let(:session) { user.sessions.create! }
  let(:client) { create(:client, user: user) }
  let(:connection) { create(:crm_connection, user: user, provider: "hubspot", status: "active") }
  let(:service) { instance_double("Crm::HubspotService") }

  before do
    cookies.signed[:session_token] = session.id
    connection
    allow(Crm::ConnectionManager).to receive(:service_for).and_return(service)
  end

  let(:contact_data) do
    {
      external_contact_id: "12345",
      email: "john@example.com",
      first_name: "John",
      last_name: "Doe",
      name: "John Doe",
      phone: "+1-555-0001",
      company_name: "Contact Company Field",
      address: { street: "123 Contact St", city: "Contactville", postal_code: "11111", state: "CA" },
      country: "US"
    }
  end

  let(:company_data) do
    {
      hubspot_id: "67890",
      company_name: "Acme Corporation",
      phone: "+1-555-0099",
      domain: "acme.com",
      country: "FR",
      company_id: "REG-42",
      address: { street: "456 Corp Ave", city: "Biztown", postal_code: "99999", state: "IL" }
    }
  end

  context "when client has a CRM link with both contact and company IDs" do
    before do
      create(:crm_client_link,
        client: client,
        crm_connection: connection,
        external_contact_id: "12345",
        external_company_id: "67890")
      allow(service).to receive(:fetch_contact).with("12345").and_return(contact_data)
      allow(service).to receive(:fetch_company).with("67890").and_return(company_data)
    end

    it "returns merged contact+company data" do
      get "/clients/#{client.id}/crm_contact_details"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      # Contact identity fields remain from the contact
      expect(json["name"]).to eq("John Doe")
      expect(json["email"]).to eq("john@example.com")

      # Company fields are overridden from the company object
      expect(json["company_name"]).to eq("Acme Corporation")
      expect(json["company_id"]).to eq("REG-42")
      expect(json["domain"]).to eq("acme.com")
      expect(json["country"]).to eq("FR")
      expect(json["phone"]).to eq("+1-555-0099")

      # Address comes from company
      expect(json["address"]["street"]).to eq("456 Corp Ave")
      expect(json["address"]["city"]).to eq("Biztown")
      expect(json["address"]["postal_code"]).to eq("99999")
    end
  end

  context "when client has a CRM link with contact only (no company)" do
    before do
      create(:crm_client_link,
        client: client,
        crm_connection: connection,
        external_contact_id: "12345",
        external_company_id: nil)
      allow(service).to receive(:fetch_contact).with("12345").and_return(contact_data)
    end

    it "returns raw contact data without company overrides" do
      get "/clients/#{client.id}/crm_contact_details"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["name"]).to eq("John Doe")
      expect(json["phone"]).to eq("+1-555-0001")
      expect(json["company_name"]).to eq("Contact Company Field")
      expect(json["address"]["street"]).to eq("123 Contact St")
    end
  end

  context "when company fetch fails gracefully" do
    before do
      create(:crm_client_link,
        client: client,
        crm_connection: connection,
        external_contact_id: "12345",
        external_company_id: "67890")
      allow(service).to receive(:fetch_contact).with("12345").and_return(contact_data)
      allow(service).to receive(:fetch_company).with("67890").and_raise(StandardError, "API timeout")
    end

    it "still returns contact data" do
      get "/clients/#{client.id}/crm_contact_details"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["name"]).to eq("John Doe")
      expect(json["phone"]).to eq("+1-555-0001")
    end
  end

  context "when there is no CRM link" do
    it "returns bad_request" do
      get "/clients/#{client.id}/crm_contact_details"

      expect(response).to have_http_status(:bad_request)
    end
  end

  context "when there is no active CRM connection" do
    before do
      connection.update!(status: "inactive")
      create(:crm_client_link,
        client: client,
        crm_connection: connection,
        external_contact_id: "12345")
    end

    it "returns not_found" do
      get "/clients/#{client.id}/crm_contact_details"

      expect(response).to have_http_status(:not_found)
    end
  end
end
