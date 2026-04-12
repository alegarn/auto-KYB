require 'rails_helper'
require 'stringio'

RSpec.describe GeminiPdfInput do
  describe '.build' do
    it 'builds an inline_data PDF part from an IO object' do
      pdf_io = StringIO.new("%PDF-1.4\nhello")

      result = described_class.build(pdf_io)

      expect(result).to eq(
        inline_data: {
          mime_type: 'application/pdf',
          data: Base64.strict_encode64("%PDF-1.4\nhello")
        }
      )
    end

    it 'rewinds the uploaded file after reading' do
      pdf_io = StringIO.new("%PDF-1.4\nhello")
      pdf_io.read(3)

      described_class.build(pdf_io)

      expect(pdf_io.pos).to eq(0)
    end

    it 'raises a clear error when the input is invalid' do
      expect { described_class.build(nil) }.to raise_error(GeminiPdfInput::InvalidFileError, 'PDF file is required')
      expect { described_class.build(StringIO.new('')) }.to raise_error(GeminiPdfInput::InvalidFileError, 'PDF file is empty')
    end
  end
end
