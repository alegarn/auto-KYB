class UploadedFilesController < ApplicationController

  before_action :set_uploaded_file

  def download
    result = FileDownloadService.call(
      uploaded_file: @uploaded_file,
      user: current_user
    )

    if result.success?
      redirect_to result.url, allow_other_host: true
    else
      redirect_back fallback_location: clients_path, alert: result.error
    end
  end

  def destroy
    unless @uploaded_file.available?
      redirect_back fallback_location: clients_path, alert: "File is no longer available"
      return
    end

    @uploaded_file.mark_deleted!
    @uploaded_file.update!(status: "downloaded")
    PurgeFileJob.perform_later(@uploaded_file.id)

    Rails.logger.info(
      "[FileAudit] Deleted file=#{@uploaded_file.id} user=#{current_user.id} at=#{Time.current}"
    )

    redirect_back fallback_location: clients_path, notice: "File deleted"
  end

  private

  def set_uploaded_file
    @uploaded_file = UploadedFile.find(params[:id])

    unless @uploaded_file.client.user_id == current_user.id
      redirect_to clients_path, alert: "Unauthorized"
    end
  end

end
