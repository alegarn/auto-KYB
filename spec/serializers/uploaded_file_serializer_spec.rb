require "rails_helper"

RSpec.describe UploadedFileSerializer do
  def build_file(id:, field_key: nil, purge_scheduled_at: nil)
    field_key ||= "field_#{id}"
    Struct.new(:id, :field_key, :filename, :content_type, :status, :byte_size, :uploaded_at, :downloaded_at, :purge_scheduled_at).new(
      id,
      field_key,
      "file_#{id}.pdf",
      "application/pdf",
      "uploaded",
      1000 + id,
      Time.now.utc,
      nil,
      purge_scheduled_at
    )
  end
  describe "#as_json" do
    it "returns nil when given nil" do
      expect(described_class.new(nil).as_json).to be_nil
    end

    context "with an uploaded file" do
      let(:purge_time) { 2.days.from_now }
      let(:uploaded_file) { build_file(id: 1, purge_scheduled_at: purge_time) }

      subject { described_class.new(uploaded_file).as_json }

      it "includes core attributes" do
        expect(subject).to include(
          "id" => uploaded_file.id,
          "field_key" => uploaded_file.field_key,
          "filename" => uploaded_file.filename,
          "content_type" => uploaded_file.content_type,
          "status" => uploaded_file.status
        )
      end

      it "includes size and timestamp metadata" do
        expect(subject["byte_size"]).to eq(uploaded_file.byte_size)
        expect(subject["uploaded_at"]).to eq(uploaded_file.uploaded_at&.iso8601)
        expect(subject["downloaded_at"]).to eq(uploaded_file.downloaded_at&.iso8601)
        expect(subject["purge_scheduled_at"]).to eq(uploaded_file.purge_scheduled_at&.iso8601)
      end
    end
  end

  describe ".collection" do
    it "serializes a collection to an array of hashes" do
      files = [ build_file(id: 1), build_file(id: 2) ]
      result = described_class.collection(files)
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Hash))
    end
  end

  describe ".by_field_key" do
    it "returns a hash keyed by field_key" do
      f1 = build_file(id: 1, field_key: "one")
      f2 = build_file(id: 2, field_key: "two")

      result = described_class.by_field_key([ f1, f2 ])

      expect(result.keys).to contain_exactly("one", "two")
      expect(result["one"]["id"]).to eq(f1.id)
      expect(result["two"]["id"]).to eq(f2.id)
    end
  end
end
