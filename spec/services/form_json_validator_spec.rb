require 'rails_helper'

RSpec.describe FormJsonValidator do
  def base_payload
    {
      'name' => 'Imported Form',
      'structure' => {
        'description' => 'Imported from PDF',
        'settings' => {
          'primary_color' => '#111111',
          'form_background_color' => '#f4f4f5',
          'header_background_color' => '#ffffff'
        },
        'fields' => [
          {
            'label' => 'Company name',
            'field_type' => 'text',
            'required' => true,
            'position' => 4,
            'metadata' => {}
          }
        ]
      }
    }
  end

  describe '.call' do
    it 'returns valid for well-formed input' do
      result = described_class.call(base_payload)

      expect(result.valid).to be(true)
      expect(result.data['name']).to eq('Imported Form')
      expect(result.data.dig('structure', 'fields', 0, 'position')).to eq(1)
    end

    it 'returns errors for missing name' do
      payload = base_payload.tap { |value| value.delete('name') }

      result = described_class.call(payload)

      expect(result.valid).to be(false)
      expect(result.errors).to include("Missing 'name'")
    end

    it 'returns errors for missing structure fields' do
      payload = base_payload
      payload['structure']['fields'] = nil

      result = described_class.call(payload)

      expect(result.valid).to be(false)
      expect(result.errors).to include("Missing or empty 'structure.fields'")
    end

    it 'corrects unknown field types to text and adds a warning' do
      payload = base_payload
      payload['structure']['fields'][0]['field_type'] = 'currency'

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'field_type')).to eq('text')
      expect(result.warnings).to include("1 field(s) had unknown types and were defaulted to 'text'")
    end

    it 'adds placeholder options to choice fields missing them' do
      payload = base_payload
      payload['structure']['fields'][0] = {
        'label' => 'Status',
        'field_type' => 'select',
        'required' => false,
        'position' => 9,
        'metadata' => {}
      }

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'metadata', 'options')).to eq([ 'Option 1', 'Option 2' ])
      expect(result.warnings.first).to match(/options were missing, added placeholders/)
    end

    it 'removes blank or duplicate choice options' do
      payload = base_payload
      payload['structure']['fields'][0] = {
        'label' => 'Status',
        'field_type' => 'select',
        'required' => false,
        'metadata' => { 'options' => [ 'Active', ' ', 'Active', ' Pending ' ] }
      }

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'metadata', 'options')).to eq([ 'Active', 'Pending' ])
      expect(result.warnings).to include("Field 'Status' (select): duplicate or blank options were removed")
    end

    it 'fixes position gaps and normalizes metadata to a hash' do
      payload = base_payload
      payload['structure']['fields'] = [
        {
          'label' => 'First field',
          'field_type' => 'text',
          'required' => false,
          'position' => 3,
          'metadata' => 'invalid'
        },
        {
          'label' => 'Second field',
          'field_type' => 'text',
          'required' => false,
          'position' => 8,
          'metadata' => {}
        }
      ]

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'position')).to eq(1)
      expect(result.data.dig('structure', 'fields', 1, 'position')).to eq(2)
      expect(result.data.dig('structure', 'fields', 0, 'metadata')).to eq({})
    end

    it 'preserves settings and description' do
      result = described_class.call(base_payload)

      expect(result.data.dig('structure', 'description')).to eq('Imported from PDF')
      expect(result.data.dig('structure', 'settings')).to eq(
        'primary_color' => '#111111',
        'form_background_color' => '#f4f4f5',
        'header_background_color' => '#ffffff'
      )
    end

    it 'falls back to default settings when settings is malformed' do
      payload = base_payload
      payload['structure']['settings'] = 'oops'

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'settings')).to eq(
        'primary_color' => '#2563eb',
        'form_background_color' => '#ffffff',
        'header_background_color' => '#f8fafc'
      )
    end

    it 'generates context-aware export keys for repeated labels in different sections' do
      payload = base_payload
      payload['structure']['fields'] = [
        {
          'label' => 'KYC',
          'field_type' => 'section',
          'required' => false,
          'metadata' => {}
        },
        {
          'label' => 'Phone Number',
          'field_type' => 'text',
          'required' => false,
          'metadata' => {}
        },
        {
          'label' => 'KYB',
          'field_type' => 'section',
          'required' => false,
          'metadata' => {}
        },
        {
          'label' => 'Phone Number',
          'field_type' => 'text',
          'required' => false,
          'metadata' => {}
        }
      ]

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 1, 'metadata', 'export_key')).to eq('phone_number_kyc')
      expect(result.data.dig('structure', 'fields', 3, 'metadata', 'export_key')).to eq('phone_number_kyb')
      expect(result.warnings).to include(
        "Generated unique export keys for duplicate field 'Phone Number': phone_number_kyc, phone_number_kyb"
      )
    end

    it 'falls back to numeric suffixes when repeated labels share the same section context' do
      payload = base_payload
      payload['structure']['fields'] = [
        {
          'label' => 'KYC',
          'field_type' => 'section',
          'required' => false,
          'metadata' => {}
        },
        {
          'label' => 'Phone Number',
          'field_type' => 'text',
          'required' => false,
          'metadata' => {}
        },
        {
          'label' => 'Phone Number',
          'field_type' => 'text',
          'required' => false,
          'metadata' => {}
        }
      ]

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 1, 'metadata', 'export_key')).to eq('phone_number_kyc')
      expect(result.data.dig('structure', 'fields', 2, 'metadata', 'export_key')).to eq('phone_number_kyc_2')
      expect(result.warnings).to include(
        "Generated unique export keys for duplicate field 'Phone Number': phone_number_kyc, phone_number_kyc_2"
      )
    end

    it 'removes malformed nested file metadata and warns' do
      payload = base_payload
      payload['structure']['fields'][0] = {
        'label' => 'Certificate upload',
        'field_type' => 'file',
        'required' => false,
        'metadata' => { 'file' => 123 }
      }

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'metadata')).to eq({})
      expect(result.warnings).to include("Field 'Certificate upload' had invalid file metadata and it was removed")
    end

    it 'removes invalid file size metadata and warns' do
      payload = base_payload
      payload['structure']['fields'][0] = {
        'label' => 'Certificate upload',
        'field_type' => 'file',
        'required' => false,
        'metadata' => { 'file' => { 'max_size_kb' => 'abc' } }
      }

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'metadata')).to eq({})
      expect(result.warnings).to include("Field 'Certificate upload' had invalid file size metadata and it was removed")
    end

    it 'replaces malformed nested table columns and warns' do
      payload = base_payload
      payload['structure']['fields'][0] = {
        'label' => 'Ownership table',
        'field_type' => 'table',
        'required' => false,
        'metadata' => { 'columns' => [ 1 ] }
      }

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'metadata', 'columns')).to eq([
        { 'key' => 'col_1', 'label' => 'Column 1', 'type' => 'text' }
      ])
      expect(result.warnings).to include("Field 'Ownership table' (table): column 1 was invalid and replaced")
    end

    it 'replaces duplicate table column keys and warns' do
      payload = base_payload
      payload['structure']['fields'][0] = {
        'label' => 'Ownership table',
        'field_type' => 'table',
        'required' => false,
        'metadata' => {
          'columns' => [
            { 'key' => 'owner', 'label' => 'Owner', 'type' => 'text' },
            { 'key' => 'owner', 'label' => 'Second owner', 'type' => 'number' }
          ]
        }
      }

      result = described_class.call(payload)

      expect(result.valid).to be(true)
      expect(result.data.dig('structure', 'fields', 0, 'metadata', 'columns')).to eq([
        { 'key' => 'owner', 'label' => 'Owner', 'type' => 'text' },
        { 'key' => 'col_2', 'label' => 'Second owner', 'type' => 'number' }
      ])
      expect(result.warnings).to include("Field 'Ownership table' (table): duplicate column key 'owner' was replaced")
    end
  end
end
