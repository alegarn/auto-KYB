class CrmTransfer < ApplicationRecord

  belongs_to :client
  belongs_to :crm_connection

  STATUS_PENDING = "pending"
  STATUS_PROCESSING = "processing"
  STATUS_SUCCESS = "success"
  STATUS_FAILED = "failed"

  TRIGGER_MANUAL_EXPORT = "manual_export"
  TRIGGER_PORTAL_SUBMIT = "portal_submit"
  TRIGGER_CLIENT_CREATE_SYNC = "client_create_sync"
  TRIGGER_DATA_IMPORT = "data_import"
  TRIGGER_CLIENT_EDIT_SYNC = "client_edit_sync"

  FAILURE_KIND_AUTHENTICATION_ERROR = "authentication_error"
  FAILURE_KIND_AUTHORIZATION_ERROR = "authorization_error"
  FAILURE_KIND_PROVIDER_ERROR = "provider_error"
  FAILURE_KIND_VALIDATION_ERROR = "validation_error"
  FAILURE_KIND_UNKNOWN_ERROR = "unknown_error"

  STATUSES = [
    STATUS_PENDING,
    STATUS_PROCESSING,
    STATUS_SUCCESS,
    STATUS_FAILED
  ].freeze

  TRIGGERS = [
    TRIGGER_MANUAL_EXPORT,
    TRIGGER_PORTAL_SUBMIT,
    TRIGGER_CLIENT_CREATE_SYNC,
    TRIGGER_CLIENT_EDIT_SYNC,
    TRIGGER_DATA_IMPORT
  ].freeze

  FAILURE_KINDS = [
    FAILURE_KIND_AUTHENTICATION_ERROR,
    FAILURE_KIND_AUTHORIZATION_ERROR,
    FAILURE_KIND_PROVIDER_ERROR,
    FAILURE_KIND_VALIDATION_ERROR,
    FAILURE_KIND_UNKNOWN_ERROR
  ].freeze

  RETRYABLE_FAILURE_KINDS = [
    FAILURE_KIND_PROVIDER_ERROR,
    FAILURE_KIND_UNKNOWN_ERROR
  ].freeze

  RETRY_REQUEST_CONTEXT_KEYS = %w[
    source
    client_form_id
    sync_address_to_contact
  ].freeze

  RETENTION_PERIOD = 3.days

  before_validation :set_lifecycle_defaults

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :trigger, presence: true, inclusion: { in: TRIGGERS }
  validates :failure_kind, inclusion: { in: FAILURE_KINDS }, allow_nil: true
  validates :attempts_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :newest_first, -> { order(created_at: :desc) }
  scope :for_user, ->(user) {
    if user.present?
      where(
        client_id: user.clients.select(:id),
        crm_connection_id: user.crm_connections.select(:id)
      )
    else
      none
    end
  }
  scope :by_status, ->(status) { status.present? ? where(status: status) : all }
  scope :by_provider, ->(provider) {
    provider.present? ? joins(:crm_connection).where(crm_connections: { provider: provider }) : all
  }
  scope :by_trigger, ->(trigger) { trigger.present? ? where(trigger: trigger) : all }
  scope :retryable, -> {
    where(status: STATUS_FAILED, failure_kind: RETRYABLE_FAILURE_KINDS)
  }
  scope :within_retention_window, -> {
    where(arel_table[:created_at].gteq(RETENTION_PERIOD.ago))
  }
  scope :older_than_retention_cutoff, -> {
    where(arel_table[:created_at].lt(RETENTION_PERIOD.ago))
  }

  def retryable?
    status == STATUS_FAILED && RETRYABLE_FAILURE_KINDS.include?(failure_kind)
  end

  def retry_request_context
    request_context.to_h.deep_stringify_keys.slice(*RETRY_REQUEST_CONTEXT_KEYS)
  end

  private

  def set_lifecycle_defaults
    self.status = status.presence || STATUS_PENDING
    self.attempts_count = attempts_count.presence || 0
    self.request_context = (request_context || {}).deep_stringify_keys
  end

end
