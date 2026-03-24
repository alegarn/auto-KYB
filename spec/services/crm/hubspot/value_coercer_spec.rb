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
  end
end
