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
      end

      it "creates a note associated to contact if target_id is provided" do
        # We need to stub the note creation request
        allow(client).to receive(:api_request).and_return({ "id" => "note_123" })

        # We must freeze time because Time.current is used in the payload
        freeze_time do
          result = uploader.upload(uploaded_file, target_type: :contact, target_id: "101")
          
          expect(result).to eq({ file_id: "hub_file_123", name: "test.pdf" })
          
          expected_body = {
            properties: {
              hs_note_body: "Original uploaded file: test.pdf",
              hs_timestamp: Time.current.utc.iso8601,
              hs_attachment_ids: "hub_file_123"
            },
            associations: [
              {
                to: { id: "101" },
                types: [
                  { associationCategory: "HUBSPOT_DEFINED", associationTypeId: 202 }
                ]
              }
            ]
          }

          expect(client).to have_received(:api_request).with(
            method: "POST",
            path: "/crm/v3/objects/notes",
            body: expected_body
          )
        end
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
        stub_request(:post, "https://api.hubapi.com/files/v3/files").to_timeout
      end

      it "catches error and returns nil" do
        expect(Rails.logger).to receive(:error).with(/execution expired/)
        result = uploader.upload(uploaded_file)
        expect(result).to be_nil
      end
    end
  end
end
