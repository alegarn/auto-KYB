require 'rails_helper'

RSpec.describe Crm::TestPayloadBuilder do
  describe '.build' do
    let(:crm_properties) do
      {
        "hubspot" => {
          "contact" => [
            { "name" => "firstname", "type" => "string", "field_type" => "text" },
            {
              "name" => "favorite_color",
              "type" => "enumeration",
              "field_type" => "select",
              "options" => [
                { "label" => "Red", "value" => "red" },
                { "label" => "Blue", "value" => "blue" }
              ]
            },
            {
              "name" => "interests",
              "type" => "enumeration",
              "field_type" => "checkbox",
              "options" => [
                { "label" => "Music", "value" => "music" },
                { "label" => "Art", "value" => "art" },
                { "label" => "Sports", "value" => "sports" }
              ]
            }
          ],
          "company" => [
            { "name" => "domain", "type" => "string", "field_type" => "text" }
          ]
        }
      }
    end

    let(:fields) do
      [
        {
          "field_type" => "text",
          "label" => "First Name",
          "metadata" => {
            "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "firstname" } }
          }
        },
        {
          "field_type" => "select",
          "label" => "Color",
          "metadata" => {
            "options" => [ "Red", "Orange" ],
            "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "favorite_color" } }
          }
        },
        {
          "field_type" => "checkbox",
          "label" => "Interests",
          "metadata" => {
            "allow_multiple" => true,
            "options" => [ "Music", "Dance" ],
            "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "interests" } }
          }
        },
        {
          "field_type" => "text",
          "label" => "Company Domain",
          "metadata" => {
            "crm_mapping" => { "hubspot" => { "object_type" => "company", "property_name" => "domain" } }
          }
        },
        {
          "field_type" => "layout",
          "label" => "My Section",
          "metadata" => {}
        }
      ]
    end

    subject(:result) { described_class.build(fields: fields, crm_properties: crm_properties, provider: "hubspot") }

    it "populates contact data" do
      expect(result[:contact]["firstname"]).to eq("Test First Name")
    end

    it "populates enum options from crm properties correctly" do
      expect(result[:contact]["favorite_color"]).to eq("red")
      expect(result[:contact]["interests"]).to eq("music;art")
    end

    it "populates company data" do
      expect(result[:company]["domain"]).to eq("Test Company Domain")
    end

    it "skips layout fields" do
      expect(result[:contact]).not_to have_key("My Section")
      expect(result[:company]).not_to have_key("My Section")
    end

    it "builds field_metadata for choices" do
      expect(result[:field_metadata]).to have_key("favorite_color")
      expect(result[:field_metadata]["favorite_color"]).to include(
        field_type: "select",
        options: [ "Red", "Orange" ],
        allow_multiple: false,
        object_type: "contact"
      )

      expect(result[:field_metadata]).to have_key("interests")
      expect(result[:field_metadata]["interests"]).to include(
        field_type: "checkbox",
        options: [ "Music", "Dance" ],
        allow_multiple: true,
        object_type: "contact"
      )
    end

    context "with parsed compound keys" do
      let(:fields) do
        [
          {
            "field_type" => "text",
            "label" => "Phone",
            "metadata" => {
              "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "company::phone" } }
            }
          }
        ]
      end

      it "routes compound keys correctly" do
        expect(result[:company]["phone"]).to eq("Test Phone")
        expect(result[:contact]).not_to have_key("phone")
      end
    end

    context "with HubSpot enumeration properties and no-options fallback" do
      let(:crm_properties) do
        {
          "hubspot" => {
            "contact" => [
              {
                "name" => "hs_lead_status",
                "type" => "enumeration",
                "field_type" => "radio",
                "options" => [
                  { "label" => "New", "value" => "NEW" },
                  { "label" => "In Progress", "value" => "IN_PROGRESS" }
                ]
              },
              {
                "name" => "hs_buying_role",
                "type" => "enumeration",
                "field_type" => "checkbox",
                "options" => [
                  { "label" => "Blocker", "value" => "BLOCKER" },
                  { "label" => "Budget Holder", "value" => "BUDGET_HOLDER" },
                  { "label" => "Champion", "value" => "CHAMPION" }
                ]
              },
              {
                "name" => "hs_analytics_source",
                "type" => "enumeration",
                "field_type" => "select",
                "options" => [
                  { "label" => "Organic Search", "value" => "ORGANIC_SEARCH" },
                  { "label" => "Paid Search", "value" => "PAID_SEARCH" }
                ]
              },
              {
                "name" => "no_options_prop",
                "type" => "enumeration",
                "field_type" => "select",
                "options" => []
              }
            ],
            "company" => []
          }
        }
      end

      let(:fields) do
        [
          {
            "field_type" => "select",
            "label" => "Lead Status",
            "metadata" => {
              "options" => [ "New", "In Progress" ],
              "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "hs_lead_status" } }
            }
          },
          {
            "field_type" => "checkbox",
            "label" => "Buying Role",
            "metadata" => {
              "options" => [ "Blocker", "Budget Holder" ],
              "allow_multiple" => true,
              "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "hs_buying_role" } }
            }
          },
          {
            "field_type" => "select",
            "label" => "Source",
            "metadata" => {
              "options" => [ "Organic Search" ],
              "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "hs_analytics_source" } }
            }
          },
          {
            "field_type" => "select",
            "label" => "No Options Field",
            "metadata" => {
              "crm_mapping" => { "hubspot" => { "object_type" => "contact", "property_name" => "no_options_prop" } }
            }
          }
        ]
      end

      it "exports hs_lead_status using the first option internal value" do
        expect(result[:contact]["hs_lead_status"]).to eq("NEW")
      end

      it "exports hs_buying_role checkbox as joined values of the first two options" do
        expect(result[:contact]["hs_buying_role"]).to eq("BLOCKER;BUDGET_HOLDER")
      end

      it "exports hs_analytics_source select using the first option value" do
        expect(result[:contact]["hs_analytics_source"]).to eq("ORGANIC_SEARCH")
      end

      it "falls back to generic Test {label} when the CRM property has no options" do
        expect(result[:contact]["no_options_prop"]).to eq("Test No Options Field")
      end

      it "populates field_metadata for choice fields and excludes text-mapped fields" do
        expect(result[:field_metadata]).to have_key("hs_lead_status")
        expect(result[:field_metadata]["hs_lead_status"]).to include(field_type: "select", object_type: "contact")

        expect(result[:field_metadata]).to have_key("hs_buying_role")

        # text-mapped field should not be present
        expect(result[:field_metadata]).not_to have_key("firstname")
      end
    end
  end
end
