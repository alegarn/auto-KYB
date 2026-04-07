require 'rails_helper'

RSpec.describe Crm::Hubspot::ValueCoercer do
  describe '.coerce' do
    context 'with date/datetime properties' do
      it 'converts a date string to Unix millisecond timestamp' do
        result = described_class.coerce("2026-03-24", "datetime")
        expected = Date.parse("2026-03-24").in_time_zone("UTC").beginning_of_day.to_i * 1000
        expect(result).to eq(expected.to_s)
      end

      it 'converts a date string for date type' do
        result = described_class.coerce("2026-01-15", "date")
        expected = Date.parse("2026-01-15").in_time_zone("UTC").beginning_of_day.to_i * 1000
        expect(result).to eq(expected.to_s)
      end

      it 'passes through a value that is already a timestamp' do
        result = described_class.coerce("1711238400000", "datetime")
        expect(result).to eq("1711238400000")
      end

      it 'converts a Date object to millisecond timestamp' do
        date = Date.new(2026, 3, 24)
        result = described_class.coerce(date, "datetime")
        expected = date.in_time_zone("UTC").beginning_of_day.to_i * 1000
        expect(result).to eq(expected.to_s)
      end

      it 'converts a Time object to millisecond timestamp' do
        time = Time.utc(2026, 3, 24, 14, 30)
        result = described_class.coerce(time, "datetime")
        expected = time.to_date.in_time_zone("UTC").beginning_of_day.to_i * 1000
        expect(result).to eq(expected.to_s)
      end

      it 'falls back to string for unparseable date values' do
        result = described_class.coerce("not a date", "datetime")
        expect(result).to eq("not a date")
      end
    end

    context 'with number properties' do
      it 'passes through a clean numeric string' do
        expect(described_class.coerce("42.5", "number")).to eq("42.5")
      end

      it 'strips non-numeric characters' do
        expect(described_class.coerce("$1,234.56", "number")).to eq("1234.56")
      end

      it 'handles negative numbers' do
        expect(described_class.coerce("-99", "number")).to eq("-99")
      end
    end

    context 'with bool properties' do
      it 'converts truthy values' do
        %w[true 1 yes on].each do |val|
          expect(described_class.coerce(val, "bool")).to eq("true"), "Expected '#{val}' to coerce to 'true'"
        end
      end

      it 'converts falsy values' do
        %w[false 0 no off].each do |val|
          expect(described_class.coerce(val, "bool")).to eq("false"), "Expected '#{val}' to coerce to 'false'"
        end
      end
    end

    context 'with string/other properties' do
      it 'returns the value as a string' do
        expect(described_class.coerce("hello", "string")).to eq("hello")
        expect(described_class.coerce(42, "string")).to eq("42")
      end
    end

    context 'with nil inputs' do
      it 'returns empty string for nil value' do
        expect(described_class.coerce(nil, "string")).to eq("")
      end

      it 'stringifies value when property_type is nil (unknown property)' do
        expect(described_class.coerce("2026-03-24", nil)).to eq("2026-03-24")
      end
    end

    context 'with enumeration properties' do
      let(:options) do
        [
          { label: "United States", value: "US" },
          { label: "Canada", value: "CA" },
          { label: "United Kingdom", value: "GB" }
        ]
      end

      context 'when field_type is booleancheckbox' do
        let(:metadata) { { field_type: "booleancheckbox", options: [] } }

        it 'coerces truthy form values to "true"' do
          %w[true 1 yes on].each do |val|
            expect(described_class.coerce(val, "enumeration", property_metadata: metadata)).to eq("true"),
              "Expected '#{val}' to coerce to 'true'"
          end
        end

        it 'coerces falsy form values to "false"' do
          %w[false 0 no off].each do |val|
            expect(described_class.coerce(val, "enumeration", property_metadata: metadata)).to eq("false"),
              "Expected '#{val}' to coerce to 'false'"
          end
        end

        it 'coerces an empty string to "false"' do
          expect(described_class.coerce("", "enumeration", property_metadata: metadata)).to eq("false")
        end

        it 'does NOT use the options list for resolution (booleancheckbox ignores options)' do
          meta_with_options = { field_type: "booleancheckbox", options: [ { label: "Yes", value: "YES" } ] }
          expect(described_class.coerce("yes", "enumeration", property_metadata: meta_with_options)).to eq("true")
        end
      end

      context 'when field_type is a single-select (e.g. select or radio)' do
        let(:metadata) { { field_type: "select", options: options } }

        it 'matches by exact label case-insensitively and returns internal value' do
          expect(described_class.coerce("united states", "enumeration", property_metadata: metadata)).to eq("US")
          expect(described_class.coerce("CaNaDa", "enumeration", property_metadata: metadata)).to eq("CA")
        end

        it 'matches by direct internal value' do
          expect(described_class.coerce("GB", "enumeration", property_metadata: metadata)).to eq("GB")
          expect(described_class.coerce("us", "enumeration", property_metadata: metadata)).to eq("US")
        end

        it 'passes through as-is if no match is found' do
          expect(described_class.coerce("France", "enumeration", property_metadata: metadata)).to eq("France")
        end

        it 'returns the original string if options are empty' do
          empty_metadata = { field_type: "select", options: [] }
          expect(described_class.coerce("United States", "enumeration", property_metadata: empty_metadata)).to eq("United States")
        end
      end

      context 'when field_type is a multi-select (checkbox)' do
        let(:metadata) { { field_type: "checkbox", options: options } }

        it 'handles array values' do
          result = described_class.coerce([ "United States", "CA", "France" ], "enumeration", property_metadata: metadata)
          expect(result).to eq("US;CA;France")
        end

        it 'handles semicolon-separated strings' do
          result = described_class.coerce("united states;CA;France", "enumeration", property_metadata: metadata)
          expect(result).to eq("US;CA;France")
        end

        it 'handles comma-separated strings' do
          result = described_class.coerce("united states, CA ,   France", "enumeration", property_metadata: metadata)
          expect(result).to eq("US;CA;France")
        end

        it 'resolves checkbox labels to internal values for HubSpot buying role' do
          hs_buying = {
            field_type: "checkbox",
            options: [
              { label: "Blocker", value: "BLOCKER" },
              { label: "Budget Holder", value: "BUDGET_HOLDER" },
              { label: "Champion", value: "CHAMPION" },
              { label: "Decision Maker", value: "DECISION_MAKER" }
            ]
          }

          expect(described_class.coerce([ "Budget Holder" ], "enumeration", property_metadata: hs_buying)).to eq("BUDGET_HOLDER")

          expect(described_class.coerce([ "Blocker", "Champion" ], "enumeration", property_metadata: hs_buying)).to eq("BLOCKER;CHAMPION")

          expect(described_class.coerce("Blocker;Champion", "enumeration", property_metadata: hs_buying)).to eq("BLOCKER;CHAMPION")

          expect(described_class.coerce([ "Connected" ], "enumeration", property_metadata: hs_buying.merge(options: [ { label: "Connected", value: "CONNECTED" } ]))).to eq("CONNECTED")

          expect(described_class.coerce([], "enumeration", property_metadata: hs_buying)).to eq("")
        end
      end

      it 'resolves HubSpot radio label "New" to internal "NEW" for hs_lead_status' do
        hs_lead = {
          field_type: "radio",
          options: [
            { label: "New", value: "NEW" },
            { label: "In Progress", value: "IN_PROGRESS" },
            { label: "Connected", value: "CONNECTED" },
            { label: "Unqualified", value: "UNQUALIFIED" }
          ]
        }

        expect(described_class.coerce("New", "enumeration", property_metadata: hs_lead)).to eq("NEW")
        expect(described_class.coerce("Unknown Label", "enumeration", property_metadata: hs_lead)).to eq("Unknown Label")
      end
    end
  end
end
