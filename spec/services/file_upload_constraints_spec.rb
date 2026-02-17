require "rails_helper"

RSpec.describe FileUploadConstraints, type: :model do
  # Move constant stubs into per-example lifecycle to avoid global stubbing

  describe ".allowed_content_types" do
    before do
      stub_const("UploadedFile::ALLOWED_CONTENT_TYPES", ["application/pdf", "image/png"]) 
      stub_const("UploadedFile::MAX_FILE_SIZE", 5_000_000)
    end
    it "returns the configured allowed content types" do
      expect(described_class.allowed_content_types).to include("application/pdf", "image/png")
    end
  end

  describe ".max_file_size_bytes" do
    before do
      stub_const("UploadedFile::ALLOWED_CONTENT_TYPES", ["application/pdf", "image/png"]) 
      stub_const("UploadedFile::MAX_FILE_SIZE", 5_000_000)
    end
    it "returns the configured max file size" do
      expect(described_class.max_file_size_bytes).to eq(5_000_000)
    end
  end

  describe "derived helpers" do
    before do
      stub_const("UploadedFile::ALLOWED_CONTENT_TYPES", ["application/pdf", "image/png"]) 
      stub_const("UploadedFile::MAX_FILE_SIZE", 5_000_000)
    end
    it "computes allowed extensions from the content types" do
      expect(described_class.allowed_extensions).to include("pdf", "png")
    end

    it "returns human labels for allowed types" do
      expect(described_class.allowed_type_labels).to include("PDF", "PNG")
    end

    it "builds the default accept string" do
      expect(described_class.default_accept).to include('.pdf')
      expect(described_class.default_accept).to include('.png')
    end

    it "returns a human readable allowed types string" do
      expect(described_class.allowed_types_human).to include('PDF')
      expect(described_class.allowed_types_human).to include('PNG')
    end
  end

  describe ".as_json" do
    before do
      stub_const("UploadedFile::ALLOWED_CONTENT_TYPES", ["application/pdf", "image/png"]) 
      stub_const("UploadedFile::MAX_FILE_SIZE", 5_000_000)
    end
    it "returns a serializable hash of constraints" do
      json = described_class.as_json

      expect(json).to include(
        allowed_content_types: described_class.allowed_content_types,
        allowed_extensions: described_class.allowed_extensions,
        allowed_type_labels: described_class.allowed_type_labels,
        max_file_size_bytes: described_class.max_file_size_bytes,
        default_accept: described_class.default_accept
      )
    end
  end

  context "when an unknown content type is present" do
    around do |example|
      stub_const("UploadedFile::ALLOWED_CONTENT_TYPES", ["application/pdf", "application/zip"]) 
      example.run
    end

    it "falls back to mime string for unknown type labels" do
      labels = described_class.allowed_type_labels
      expect(labels).to include("PDF")
      expect(labels).to include("application/zip")
    end
  end
end
