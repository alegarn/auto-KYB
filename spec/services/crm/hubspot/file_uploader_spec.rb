require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Crm::Hubspot::FileUploader do
  let(:connection) { instance_double(CrmConnection, access_token: "fake_token") }
  let(:client) { instance_double(Crm::Hubspot::Client, connection: connection) }
  let(:uploader) { described_class.new(client) }

  let(:blob) do
    double("ActiveStorage::Blob",
      filename: double(base: "test", extension: "pdf", to_s: "test.pdf"),
      content_type: "application/pdf"
    )
  end
  let(:file) { double("Attached::One", blob: blob) }
  let(:uploaded_file) { instance_double(UploadedFile, file: file, client_id: 42) }

  before do
    allow(blob).to receive(:download).and_yield("fake file content")

    # Stub the bizarre empty POST request
    allow(client).to receive(:api_request).with(
      method: "POST",
      path: "/files/v3/files",
      body: nil,
      headers: {}
    ).and_return(nil)
  end

  describe "#upload" do
    context "when upload is successful" do
      before do
        stub_request(:post, "https://api.hubapi.com/files/v3/files").to_return(
          status: 200,
          body: { id: "hub_file_123", name: "test.pdf" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it "returns a hash with file_id and name" do
        result = uploader.upload(uploaded_file)

        expect(result).to eq({ file_id: "hub_file_123", name: "test.pdf" })
        expect(WebMock).to have_requested(:post, "https://api.hubapi.com/files/v3/files")
          .with(headers: { 'Authorization' => 'Bearer fake_token' })
      end

      it "associates to contact if associate_to_contact is provided" do
        allow(client).to receive(:api_request).with(
          method: "PUT",
          path: "/crm/v3/objects/contacts/101/associations/files/hub_file_123/1"
        ).and_return(nil)

        result = uploader.upload(uploaded_file, associate_to_contact: "101")

        expect(result).to eq({ file_id: "hub_file_123", name: "test.pdf" })
        expect(client).to have_received(:api_request).with(
          method: "PUT",
          path: "/crm/v3/objects/contacts/101/associations/files/hub_file_123/1"
        )
      end
    end

    context "when upload fails" do
      before do
        stub_request(:post, "https://api.hubapi.com/files/v3/files").to_return(
          status: 400,
          body: { message: "Invalid request" }.to_json
        )
      end

      it "returns nil" do
        result = uploader.upload(uploaded_file)
        expect(result).to be_nil
      end
    end

    context "when exception occurs" do
      before do
        allow(client).to receive(:api_request).and_raise(StandardError.new("Boom"))
      end

      it "catches error and returns nil" do
        expect(Rails.logger).to receive(:error).with(/Boom/)
        result = uploader.upload(uploaded_file)
        expect(result).to be_nil
      end
    end
  end
end
