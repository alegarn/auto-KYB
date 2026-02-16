require "rails_helper"

RSpec.describe "UploadedFiles", type: :request do
  describe "GET /uploaded_files/:id/download" do
    it "redirects to an Active Storage URL for an available file" do
      user = sign_in_user
      client = create(:client, user: user)
      uploaded_file = create(:uploaded_file, :with_file, client: client, form_response: nil)

      get download_uploaded_file_path(uploaded_file)

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to include("/rails/active_storage/")
      expect(uploaded_file.reload.status).to eq("downloaded")
    end
  end
end
