class FileUploadService

  Result = Struct.new(:success, :uploaded_file, :error, keyword_init: true) do
    def success? = success
  end

  def self.call(...)
    new(...).call
  end

  def initialize(client:, field_key:, file:, form_response: nil, client_form: nil)
    @client = client
    @field_key = field_key
    @file = file
    @form_response = form_response
    @client_form = client_form
  end

  def call
    validation = FileValidationService.validate(@file)
    unless validation.valid?
      return Result.new(success: false, error: validation.error)
    end

    replaced_file_id = nil

    result = ActiveRecord::Base.transaction do
      replaced_file_id = replace_existing_file!
      uploaded_file = create_uploaded_file!
      attach_file!(uploaded_file)
      @client_form&.mark_started!
      Result.new(success: true, uploaded_file: uploaded_file)
    end

    # Schedule purge AFTER the transaction commits so the new file is confirmed on disk.
    # A short delay gives the storage service time to finalize the write.
    if replaced_file_id
      PurgeFileJob.set(wait: 5.minutes).perform_later(replaced_file_id)
    end

    result
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, error: e.message)
  rescue ActiveStorage::IntegrityError
    Result.new(success: false, error: "File upload failed due to integrity error. Please try again.")
  rescue StandardError => e
    Rails.logger.error("[FileUpload] Unexpected error: #{e.message}")
    Result.new(success: false, error: "File upload failed. Please try again.")
  end

  private

  def replace_existing_file!
    existing = UploadedFile
      .where(client: @client, field_key: @field_key)
      .available
      .first

    return unless existing

    existing.mark_replaced!
    existing.id
  end

  def create_uploaded_file!
    UploadedFile.create!(
      client: @client,
      form_response: @form_response,
      field_key: @field_key,
      status: "available",
      uploaded_at: Time.current
    )
  end

  def attach_file!(uploaded_file)
    uploaded_file.file.attach(
      io: @file.respond_to?(:tempfile) ? @file.tempfile : @file,
      filename: @file.original_filename,
      content_type: @file.content_type
    )
  end

end
