class FileDownloadService

  SIGNED_URL_EXPIRY = 5.minutes

  Result = Struct.new(:success, :url, :error, keyword_init: true) do
    def success? = success
  end

  def self.call(...)
    new(...).call
  end

  def initialize(uploaded_file:, user:)
    @uploaded_file = uploaded_file
    @user = user
  end

  def call
    return Result.new(success: false, error: "File is no longer available for download") unless downloadable?

    unless @uploaded_file.file.attached?
      return Result.new(success: false, error: "File data not found")
    end

    url = generate_signed_url
    @uploaded_file.mark_downloaded!(user: @user) if @uploaded_file.available?
    schedule_purge_once!

    Rails.logger.info(
      "[FileAudit] Download file=#{@uploaded_file.id} user=#{@user.id} at=#{Time.current}"
    )

    Result.new(success: true, url: url)
  rescue StandardError => e
    Rails.logger.error("[FileDownload] Error: #{e.message}")
    Result.new(success: false, error: "Download failed. Please try again.")
  end

  private

  def downloadable?
    @uploaded_file.available? || @uploaded_file.downloaded?
  end

  def generate_signed_url
    @uploaded_file.file.url(
      expires_in: SIGNED_URL_EXPIRY,
      disposition: "attachment",
      filename: @uploaded_file.filename
    )
  end

  def schedule_purge_once!
    return if @uploaded_file.purge_scheduled_at.present?

    purge_at = Time.current + FileRetentionPolicy.purge_delay
    @uploaded_file.update!(purge_scheduled_at: purge_at)
    PurgeFileJob.set(wait_until: purge_at).perform_later(@uploaded_file.id)
  end

end
