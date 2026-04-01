require 'rails_helper'

RSpec.describe Crm::Hubspot::OptionNormalizer do
  describe '.internal_value' do
    it 'returns lowercase stripped string with underscores' do
      expect(described_class.internal_value('  My Option  ')).to eq('my_option')
    end

    it 'replaces non-alphanumeric with single underscores' do
      expect(described_class.internal_value('A-B! C?')).to eq('a_b_c')
    end

    it 'removes leading and trailing underscores' do
      expect(described_class.internal_value('!Hello World!')).to eq('hello_world')
    end

    it 'returns "option" for empty or non-alphanumeric only strings' do
      expect(described_class.internal_value('!!!')).to eq('option')
      expect(described_class.internal_value('')).to eq('option')
    end

    it 'normalizes HubSpot-style labels like "New" and "In Progress"' do
      expect(described_class.internal_value('New')).to eq('new')
      expect(described_class.internal_value('In Progress')).to eq('in_progress')
    end

    it 'downcases all-caps labels like "VAT"' do
      expect(described_class.internal_value('VAT')).to eq('vat')
    end
  end

  describe '.build_options' do
    it 'returns an array of hubsot options' do
      labels = ['Option A', 'Option B']
      options = described_class.build_options(labels)

      expect(options).to eq([
        { label: 'Option A', value: 'option_a', displayOrder: 0 },
        { label: 'Option B', value: 'option_b', displayOrder: 1 }
      ])
    end

    it 'handles slug collisions' do
      labels = ['Test', 'Test !!', '   Test']
      options = described_class.build_options(labels)

      expect(options).to eq([
        { label: 'Test', value: 'test', displayOrder: 0 },
        { label: 'Test !!', value: 'test_1', displayOrder: 1 },
        { label: '   Test', value: 'test_2', displayOrder: 2 }
      ])
    end

    it 'handles exact duplicate labels by appending incremental suffixes' do
      labels = ['Test', 'Test']
      options = described_class.build_options(labels)

      expect(options).to eq([
        { label: 'Test', value: 'test', displayOrder: 0 },
        { label: 'Test', value: 'test_1', displayOrder: 1 }
      ])
    end

    it 'uses "option" for empty labels in build_options' do
      labels = ['']
      options = described_class.build_options(labels)
      expect(options.first[:value]).to eq('option')
    end
  end
end
