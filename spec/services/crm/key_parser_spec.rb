require "rails_helper"

RSpec.describe Crm::KeyParser do
  describe ".build" do
    it "creates a compound key from object_type and property_name" do
      expect(described_class.build("company", "address")).to eq("company::address")
    end

    it "creates a contact compound key" do
      expect(described_class.build("contact", "email")).to eq("contact::email")
    end
  end

  describe ".parse" do
    it "extracts object_type and property_name from a compound key" do
      object_type, property_name = described_class.parse("company::address")
      expect(object_type).to eq("company")
      expect(property_name).to eq("address")
    end

    it "defaults to contact for legacy keys without separator" do
      object_type, property_name = described_class.parse("email")
      expect(object_type).to eq("contact")
      expect(property_name).to eq("email")
    end

    it "handles nil gracefully" do
      object_type, property_name = described_class.parse(nil)
      expect(object_type).to eq("contact")
      expect(property_name).to eq("")
    end

    it "handles empty string" do
      object_type, property_name = described_class.parse("")
      expect(object_type).to eq("contact")
      expect(property_name).to eq("")
    end

    it "preserves property names containing colons" do
      object_type, property_name = described_class.parse("contact::some:special:name")
      expect(object_type).to eq("contact")
      expect(property_name).to eq("some:special:name")
    end
  end

  describe ".property_name" do
    it "returns just the clean property name" do
      expect(described_class.property_name("company::domain")).to eq("domain")
    end

    it "returns the full string for legacy keys" do
      expect(described_class.property_name("domain")).to eq("domain")
    end
  end

  describe ".object_type" do
    it "returns the object type from a compound key" do
      expect(described_class.object_type("company::domain")).to eq("company")
    end

    it "defaults to contact for legacy keys" do
      expect(described_class.object_type("domain")).to eq("contact")
    end
  end

  describe ".compound?" do
    it "returns true for compound keys" do
      expect(described_class.compound?("company::address")).to be true
    end

    it "returns false for legacy keys" do
      expect(described_class.compound?("address")).to be false
    end

    it "returns false for nil" do
      expect(described_class.compound?(nil)).to be false
    end
  end
end
