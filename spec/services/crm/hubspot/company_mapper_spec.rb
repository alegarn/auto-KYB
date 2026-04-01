require "rails_helper"

RSpec.describe Crm::Hubspot::CompanyMapper do
  let(:client) do
    create(
      :client,
      company_name: "Acme Corporation",
      phone: "+1 (555) 123-4567",
      address: "123 Main St",
      country: "USA"
    )
  end
  let(:data) { { company_id: "REG12345", kyc_status: "verified" } }
  
  subject { described_class.new(client, data) }

  describe "#to_hubspot_properties" do
    it "maps client attributes to HubSpot company properties" do
      properties = subject.to_hubspot_properties
      
      expect(properties[:name]).to eq("Acme Corporation")
      expect(properties[:phone]).to eq("+1 (555) 123-4567")
      expect(properties[:address]).to eq("123 Main St")
      expect(properties[:country]).to eq("USA")
      
      expect(properties[:registration_number]).to eq("REG12345")
      expect(properties[:kyb_verification_status]).to eq("verified")
    end

    it "omits nil values" do
      client.phone = nil
      client.address = nil
      client.company_name = nil
      client.country = nil
      
      properties = subject.to_hubspot_properties

      expect(properties.keys).not_to include(:name, :phone, :address, :country)
    end
    
    context "when initialized without extra data" do
      subject { described_class.new(client) }

      it "omits custom properties missing from data" do
        properties = subject.to_hubspot_properties
        expect(properties.keys).not_to include(:registration_number, :kyb_verification_status)
      end
    end
  end
end
