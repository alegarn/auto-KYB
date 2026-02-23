require "rails_helper"

RSpec.describe "ClientPortal::UploadedFiles", type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user, form_status: :linked) }
  let(:form) { create(:form, user: user) }

  before do
    @client_form = create(:client_form, client: client, form: form, status: ClientForm.statuses["draft"])
    password = "secret-pass-#{SecureRandom.hex(4)}"
    @client_form.password = password
    @client_form.save!
    @password = password
  end

  describe "POST /client_portal/uploaded_files" do
    it "marks draft client form as filled and linked client as active on upload-only flow" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([ 302, 303 ]).to include(response.status)

      file = Tempfile.new([ "portal-upload", ".pdf" ])
      file.write("%PDF-1.4\n1 0 obj\n<<>>\nendobj\n")
      file.rewind

      uploaded_file = Rack::Test::UploadedFile.new(file.path, "application/pdf", true, original_filename: "kyb-document.pdf")

      post client_portal_uploaded_files_path,
           params: {
             file: uploaded_file,
             field_key: "company_certificate"
           }

      expect(response).to have_http_status(:created)

      @client_form.reload
      client.reload

      expect(@client_form.status).to eq(ClientForm.statuses["filled"])
      expect(client.form_status).to eq("active")
    ensure
      file.close!
    end

    it "does not change statuses when upload validation fails" do
      post client_portal_login_path(@client_form.access_token), params: { password: @password }
      expect([ 302, 303 ]).to include(response.status)

      invalid = Tempfile.new([ "portal-upload", ".txt" ])
      invalid.write("not an allowed document")
      invalid.rewind

      uploaded_file = Rack::Test::UploadedFile.new(invalid.path, "text/plain", true, original_filename: "note.txt")

      post client_portal_uploaded_files_path,
           params: {
             file: uploaded_file,
             field_key: "company_certificate"
           }

      expect(response).to have_http_status(:unprocessable_entity)

      @client_form.reload
      client.reload

      expect(@client_form.status).to eq(ClientForm.statuses["draft"])
      expect(client.form_status).to eq("linked")
    ensure
      invalid.close!
    end
  end
end
