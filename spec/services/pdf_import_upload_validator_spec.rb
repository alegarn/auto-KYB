require 'rails_helper'

RSpec.describe PdfImportUploadValidator do
  def with_upload(content:, filename:, content_type: 'application/pdf')
    Tempfile.create([ File.basename(filename, '.*'), File.extname(filename) ]) do |file|
      file.binmode
      file.write(content)
      file.rewind
      uploaded_file = Rack::Test::UploadedFile.new(file.path, content_type, true, original_filename: filename)
      yield uploaded_file
    end
  end

  it 'accepts a valid PDF upload' do
    with_upload(content: "%PDF-1.4\nhello", filename: 'import.pdf') do |uploaded_file|
      result = described_class.validate(uploaded_file)

      expect(result).to be_valid
      expect(result.error).to be_nil
    end
  end

  it 'rejects non-upload inputs' do
    result = described_class.validate('bad-input')

    expect(result).not_to be_valid
    expect(result.error).to eq('Only PDF files are accepted')
  end

  it 'rejects oversized uploads' do
    oversized_content = "%PDF-" + ('a' * (10.megabytes + 1))

    with_upload(content: oversized_content, filename: 'large.pdf') do |uploaded_file|
      result = described_class.validate(uploaded_file)

      expect(result).not_to be_valid
      expect(result.error).to eq('File too large (max 10 MB)')
    end
  end

  it 'rejects uploads without a PDF signature' do
    with_upload(content: 'plain text', filename: 'fake.pdf') do |uploaded_file|
      result = described_class.validate(uploaded_file)

      expect(result).not_to be_valid
      expect(result.error).to eq('Only PDF files are accepted')
    end
  end
end
