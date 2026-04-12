require 'rails_helper'
require 'stringio'

RSpec.describe PdfFormImportService do
  let(:pdf_file) { StringIO.new("%PDF-1.4\nhello") }

  describe '.call' do
    it 'returns success with valid sanitized data when the pipeline succeeds' do
      allow(GeminiClient).to receive(:generate).and_return('ignored')
      allow(FormJsonExtractor).to receive(:call).and_return(
        'name' => '<b>Imported Form</b>',
        'structure' => {
          'description' => '<p>Intro</p>',
          'fields' => [
            {
              'label' => '<script>alert(1)</script>Company name',
              'field_type' => 'select',
              'required' => true,
              'position' => 1,
              'metadata' => {
                'description' => '<em>Required</em>',
                'options' => [ '<strong>Option A</strong>' ]
              }
            }
          ]
        }
      )

      result = described_class.call(pdf_file)

      expect(result.success).to be(true)
      expect(result.errors).to eq([])
      expect(result.data['name']).to eq('Imported Form')
      expect(result.data.dig('structure', 'description')).to eq('Intro')
      expect(result.data.dig('structure', 'fields', 0, 'label')).to eq('alert(1)Company name')
      expect(result.data.dig('structure', 'fields', 0, 'metadata', 'description')).to eq('Required')
      expect(result.data.dig('structure', 'fields', 0, 'metadata', 'options')).to eq([ 'Option A' ])
    end

    it 'propagates GeminiClient errors' do
      allow(GeminiClient).to receive(:generate).and_raise(GeminiClient::ApiError, 'upstream failed')

      expect {
        described_class.call(pdf_file)
      }.to raise_error(GeminiClient::ApiError, 'upstream failed')
    end
  end

  describe '.normalize_form_data' do
    it 'returns failure when validation fails' do
      result = described_class.normalize_form_data('structure' => { 'fields' => [] })

      expect(result.success).to be(false)
      expect(result.errors).to include("Missing 'name'", "Missing or empty 'structure.fields'")
    end

    it 'rejects fields whose labels become blank after sanitization' do
      result = described_class.normalize_form_data(
        'name' => 'Imported Form',
        'structure' => {
          'fields' => [
            {
              'label' => '<strong></strong>',
              'field_type' => 'text',
              'required' => true,
              'metadata' => {}
            }
          ]
        }
      )

      expect(result.success).to be(false)
      expect(result.errors).to include("Field at position 1 is missing 'label'")
    end

    it 'sanitizes validation warnings before returning them' do
      result = described_class.normalize_form_data(
        'name' => 'Imported Form',
        'structure' => {
          'fields' => [
            {
              'label' => '<script>alert(1)</script>Company name',
              'field_type' => 'text',
              'required' => false,
              'metadata' => 'invalid'
            }
          ]
        }
      )

      expect(result.success).to be(true)
      expect(result.warnings).to eq([ "Field 'alert(1)Company name' had invalid metadata and was reset" ])
    end

    it 'generates unique export keys when duplicate labels appear in separate sections' do
      result = described_class.normalize_form_data(
        'name' => 'Imported Form',
        'structure' => {
          'fields' => [
            {
              'label' => 'KYC',
              'field_type' => 'section',
              'required' => false,
              'metadata' => {}
            },
            {
              'label' => 'Phone Number',
              'field_type' => 'text',
              'required' => true,
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
        }
      )

      expect(result.success).to be(true)
      expect(result.data.dig('structure', 'fields', 1, 'metadata', 'export_key')).to eq('phone_number_kyc')
      expect(result.data.dig('structure', 'fields', 3, 'metadata', 'export_key')).to eq('phone_number_kyb')
      expect(result.warnings).to include(
        "Generated unique export keys for duplicate field 'Phone Number': phone_number_kyc, phone_number_kyb"
      )
    end

    it 'uses numeric suffixes when duplicate labels repeat within the same section' do
      result = described_class.normalize_form_data(
        'name' => 'Imported Form',
        'structure' => {
          'fields' => [
            {
              'label' => 'KYC',
              'field_type' => 'section',
              'required' => false,
              'metadata' => {}
            },
            {
              'label' => 'Phone Number',
              'field_type' => 'text',
              'required' => true,
              'metadata' => {}
            },
            {
              'label' => 'Phone Number',
              'field_type' => 'text',
              'required' => false,
              'metadata' => {}
            }
          ]
        }
      )

      expect(result.success).to be(true)
      expect(result.data.dig('structure', 'fields', 1, 'metadata', 'export_key')).to eq('phone_number_kyc')
      expect(result.data.dig('structure', 'fields', 2, 'metadata', 'export_key')).to eq('phone_number_kyc_2')
      expect(result.warnings).to include(
        "Generated unique export keys for duplicate field 'Phone Number': phone_number_kyc, phone_number_kyc_2"
      )
    end

    it 'keeps the most specific section and subtitle context before adding numeric suffixes' do
      result = described_class.normalize_form_data(
        'name' => 'Imported Form',
        'structure' => {
          'fields' => [
            {
              'label' => 'KYC',
              'field_type' => 'section',
              'required' => false,
              'metadata' => {}
            },
            {
              'label' => 'Primary Contact',
              'field_type' => 'subtitle',
              'required' => false,
              'metadata' => {}
            },
            {
              'label' => 'Phone Number',
              'field_type' => 'text',
              'required' => true,
              'metadata' => {}
            },
            {
              'label' => 'Phone Number',
              'field_type' => 'text',
              'required' => false,
              'metadata' => {}
            }
          ]
        }
      )

      expect(result.success).to be(true)
      expect(result.data.dig('structure', 'fields', 2, 'metadata', 'export_key')).to eq('phone_number_kyc_primary_contact')
      expect(result.data.dig('structure', 'fields', 3, 'metadata', 'export_key')).to eq('phone_number_kyc_primary_contact_2')
      expect(result.warnings).to include(
        "Generated unique export keys for duplicate field 'Phone Number': phone_number_kyc_primary_contact, phone_number_kyc_primary_contact_2"
      )
    end
  end
end
