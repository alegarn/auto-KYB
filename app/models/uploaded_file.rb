class UploadedFile < ApplicationRecord

  ALLOWED_CONTENT_TYPES = %w[application/pdf image/jpeg image/png].freeze
  MAX_FILE_SIZE = 10.megabytes
  STATUSES = %w[available downloaded replaced deleted purged].freeze

  belongs_to :form_response, optional: true
  belongs_to :client
  belongs_to :downloaded_by_user, class_name: "User", optional: true
  has_one_attached :file

  validates :field_key, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :available, -> { where(status: "available") }
  scope :for_field, ->(field_key) { where(field_key: field_key) }
  scope :for_client, ->(client_id) { where(client_id: client_id) }

  after_create :log_upload
  after_update :log_status_change, if: :saved_change_to_status?

  def available?
    status == "available"
  end

  def downloaded?
    status == "downloaded"
  end

  def replaced?
    status == "replaced"
  end

  def purged?
    status == "purged"
  end

  def mark_downloaded!(user:)
    attrs = {
      status: "downloaded",
      downloaded_by_user: user
    }
    attrs[:downloaded_at] = Time.current if downloaded_at.blank?

    update!(attrs)
  end

  def mark_replaced!
    update!(
      status: "replaced",
      deleted_at: Time.current
    )
  end

  def mark_purged!
    update!(status: "purged")
  end

  # Explicit user deletion/revocation
  def mark_deleted!
    update!(
      status: "deleted",
      deleted_at: Time.current
    )
  end

  def filename
    file.attached? ? file.filename.to_s : nil
  end

  def content_type
    file.attached? ? file.content_type : nil
  end

  def byte_size
    file.attached? ? file.byte_size : nil
  end

  private

  def log_upload
    Rails.logger.info("[FileAudit] Uploaded file=#{id} client=#{client_id} field=#{field_key} at=#{uploaded_at}")
  end

  def log_status_change
    Rails.logger.info("[FileAudit] Status change file=#{id} status=#{status} at=#{Time.current}")
  end

end
