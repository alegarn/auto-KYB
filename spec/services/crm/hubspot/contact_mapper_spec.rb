require "rails_helper"

RSpec.describe Crm::Hubspot::ContactMapper do
  let(:client) { create(:client, name: "John Doe", email: "john@example.com", phone: "+1234567890", company_name: "Acme Corp", address: "123 Main St") }
  let(:data) { { country: "USA", kyc_status: "verified", risk_score: "low", sync_address_to_contact: "true" } }
  
  subject { described_class.new(client, data) }

  describe "#to_hubspot_properties" do
    it "maps client attributes to HubSpot contact properties" do
      properties = subject.to_hubspot_properties

      expect(properties[:email]).to eq("john@example.com")
      expect(properties[:phone]).to eq("+1234567890")
      expect(properties[:company]).to eq("Acme Corp")
      expect(properties[:address]).to eq("123 Main St")
      
      expect(properties[:firstname]).to eq("John")
      expect(properties[:lastname]).to eq("Doe")
      
      expect(properties[:country]).to eq("USA")
      expect(properties[:kyb_verification_status]).to eq("verified")
      expect(properties[:kyb_risk_score]).to eq("low")
    end

    it "handles missing name gracefully" do
      client.name = nil
      properties = subject.to_hubspot_properties
      
      expect(properties.keys).not_to include(:firstname, :lastname)
    end

    it "handles single name gracefully" do
      client.name = "Prince"
      properties = subject.to_hubspot_properties
      
      expect(properties[:firstname]).to eq("Prince")
      expect(properties[:lastname]).to eq("")
    end

    it "compacts nil values from the output" do
      client.email = nil
      client.phone = nil
      properties = subject.to_hubspot_properties

      expect(properties.keys).not_to include(:email, :phone)
    end
    
    context "when data is optionally omitted" do
      subject { described_class.new(client) }

      it "does not include custom properties if missing from data" do
        properties = subject.to_hubspot_properties
        expect(properties.keys).not_to include(:country, :kyb_verification_status, :kyb_risk_score)
      end
    end
  end
end
