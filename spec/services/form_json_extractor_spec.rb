require 'rails_helper'

RSpec.describe FormJsonExtractor do
  describe '.call' do
    it 'parses clean JSON directly' do
      result = described_class.call('{"name":"Imported","structure":{"fields":[{"label":"Name"}]}}')

      expect(result['name']).to eq('Imported')
    end

    it 'strips markdown code fences and parses' do
      result = described_class.call("```json\n{\"name\":\"Imported\",\"structure\":{\"fields\":[{\"label\":\"Name\"}]}}\n```")

      expect(result['name']).to eq('Imported')
    end

    it 'extracts JSON from surrounding prose' do
      raw = <<~TEXT
        Here is your JSON payload.

        {"name":"Imported","structure":{"fields":[{"label":"Name"}]}}

        Please review it.
      TEXT

      result = described_class.call(raw)

      expect(result['name']).to eq('Imported')
    end

    it 'raises ExtractionError when no JSON is found' do
      expect {
        described_class.call('No JSON here')
      }.to raise_error(FormJsonExtractor::ExtractionError, /Could not extract valid JSON/)
    end

    it 'handles nested braces correctly' do
      raw = <<~TEXT
        Response:
        {"name":"Imported","structure":{"fields":[{"label":"Address","metadata":{"description":"Use {official} address"}}]}}
      TEXT

      result = described_class.call(raw)

      expect(result.dig('structure', 'fields', 0, 'metadata', 'description')).to eq('Use {official} address')
    end
  end
end
