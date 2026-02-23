class PurgeFileJob < ApplicationJob

  queue_as :default

  def perform(uploaded_file_id)
    uploaded_file = UploadedFile.find_by(id: uploaded_file_id)
    return unless uploaded_file
    return if uploaded_file.purged?
    return if uploaded_file.available?

    if uploaded_file.downloaded?
      return if uploaded_file.purge_scheduled_at.blank?
      return if Time.current < uploaded_file.purge_scheduled_at
    end

    if uploaded_file.file.attached?
      uploaded_file.file.purge
    end

    uploaded_file.mark_purged!

    Rails.logger.info("[FileAudit] Purged file=#{uploaded_file_id} at=#{Time.current}")
  rescue StandardError => e
    Rails.logger.error("[FilePurge] Error purging file=#{uploaded_file_id}: #{e.message}")
    raise
  end

end
