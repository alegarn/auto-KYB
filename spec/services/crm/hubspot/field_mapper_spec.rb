require "rails_helper"

RSpec.describe Crm::Hubspot::FieldMapper do
  let(:client) do
    create(:client,
      name: "John Doe",
      email: "john@example.com",
      phone: "+123456789",
      address: {
        "street" => "123 Main St",
        "city" => "Paris",
        "postal_code" => "75001",
        "state" => "IDF"
      },
      country: "France"
    )
  end

  describe ".map_to_hubspot" do
    context "when sync_address_to_contact is 'true'" do
      let(:extra_data) { { sync_address_to_contact: "true" } }

      it "includes address fields in the contact properties" do
        contact_props = described_class.map_to_hubspot(client, extra_data)

        expect(contact_props[:address]).to eq("123 Main St")
        expect(contact_props[:city]).to eq("Paris")
        expect(contact_props[:zip]).to eq("75001")
        expect(contact_props[:state]).to eq("IDF")
        expect(contact_props[:country]).to eq("France")
      end

      it "includes basic contact info" do
        contact_props = described_class.map_to_hubspot(client, extra_data)

        expect(contact_props[:firstname]).to eq("John")
        expect(contact_props[:lastname]).to eq("Doe")
        expect(contact_props[:email]).to eq("john@example.com")
      end
    end

    context "when sync_address_to_contact is false or missing" do
      let(:extra_data) { { sync_address_to_contact: "false" } }

      it "excludes address fields from the contact properties" do
        contact_props = described_class.map_to_hubspot(client, extra_data)

        expect(contact_props).not_to have_key(:address)
        expect(contact_props).not_to have_key(:city)
        expect(contact_props).not_to have_key(:zip)
        expect(contact_props).not_to have_key(:country)
      end

      it "still includes basic contact info" do
        contact_props = described_class.map_to_hubspot(client, extra_data)

        expect(contact_props[:firstname]).to eq("John")
        expect(contact_props[:lastname]).to eq("Doe")
      end
    end

    context "when is_company is true" do
      let(:extra_data) { { is_company: true } }

      it "always includes address fields regardless of sync_address_to_contact" do
        company_props = described_class.map_to_hubspot(client, extra_data)

        expect(company_props[:address]).to eq("123 Main St")
        expect(company_props[:city]).to eq("Paris")
        expect(company_props[:zip]).to eq("75001")
        expect(company_props[:country]).to eq("France")
      end
    end
  end
end
