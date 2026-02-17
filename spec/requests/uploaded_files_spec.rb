require "rails_helper"

RSpec.describe "UploadedFiles", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    original_delay = ENV["UPLOADED_FILE_PURGE_DELAY_SECONDS"]
    ENV["UPLOADED_FILE_PURGE_DELAY_SECONDS"] = "86400"
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
    ENV["UPLOADED_FILE_PURGE_DELAY_SECONDS"] = original_delay
  end

  describe "GET /uploaded_files/:id/download" do
    it "marks first successful download and schedules delayed purge" do
      user = sign_in_user
      client = create(:client, user: user)
      uploaded_file = create(:uploaded_file, :with_file, client: client, form_response: nil)

      travel_to(Time.zone.parse("2026-02-16 10:00:00 UTC")) do
        expect {
          get download_uploaded_file_path(uploaded_file)
        }.to have_enqueued_job(PurgeFileJob).with(uploaded_file.id)

        expect(response).to have_http_status(:found)
        expect(response.headers["Location"]).to include("/rails/active_storage/")

        uploaded_file.reload
        expect(uploaded_file.status).to eq("downloaded")
        expect(uploaded_file.downloaded_at).to eq(Time.current)
        expect(uploaded_file.purge_scheduled_at).to eq(1.day.from_now)
      end
    end

    it "allows retry before purge window ends without rescheduling" do
      user = sign_in_user
      client = create(:client, user: user)
      uploaded_file = create(:uploaded_file, :with_file, client: client, form_response: nil)

      initial_download_time = Time.zone.parse("2026-02-16 10:00:00 UTC")

      travel_to(initial_download_time) do
        get download_uploaded_file_path(uploaded_file)
      end

      uploaded_file.reload
      first_downloaded_at = uploaded_file.downloaded_at
      first_purge_scheduled_at = uploaded_file.purge_scheduled_at

      clear_enqueued_jobs

      travel_to(initial_download_time + 2.hours) do
        expect {
          get download_uploaded_file_path(uploaded_file)
        }.not_to have_enqueued_job(PurgeFileJob)

        expect(response).to have_http_status(:found)

        uploaded_file.reload
        expect(uploaded_file.status).to eq("downloaded")
        expect(uploaded_file.downloaded_at).to eq(first_downloaded_at)
        expect(uploaded_file.purge_scheduled_at).to eq(first_purge_scheduled_at)
      end
    end

    it "rejects download after file has been deleted" do
      user = sign_in_user
      client = create(:client, user: user)
      uploaded_file = create(:uploaded_file, :with_file, client: client, form_response: nil, status: "deleted")

      get download_uploaded_file_path(uploaded_file)

      expect(response).to redirect_to(clients_path)
      expect(flash[:alert]).to eq("File is no longer available for download")
    end
  end
end
