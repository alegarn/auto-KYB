class CrmTransferSignalsQuery
  def initialize(user:, toast_seen_at:)
    @user = user
    @toast_seen_at = parse_timestamp(toast_seen_at)
  end

  def call
    {
      unread_failed_count: unread_failed_scope.count,
      unread_retryable_count: unread_failed_scope.retryable.count,
      latest_unread_failure_at: latest_unread_failure_at,
      toast: toast_payload
    }
  end

  private

  attr_reader :user, :toast_seen_at

  def transfer_scope
    @transfer_scope ||= CrmTransfer
      .joins(:client, :crm_connection)
      .where(clients: { user_id: user.id }, crm_connections: { user_id: user.id })
      .within_retention_window
  end

  def unread_failed_scope
    @unread_failed_scope ||= begin
      scope = transfer_scope.where(status: CrmTransfer::STATUS_FAILED)
      last_seen_at = durable_last_seen_at

      last_seen_at.present? ? scope.where(CrmTransfer.arel_table[:created_at].gt(last_seen_at)) : scope
    end
  end

  def latest_unread_failure_at
    @latest_unread_failure_at ||= unread_failed_scope.maximum(:created_at)&.iso8601
  end

  def toast_payload
    return nil if unread_failed_scope.count.zero?
    return nil if latest_unread_failure_time.blank?
    return nil if toast_seen_at.present? && latest_unread_failure_time <= toast_seen_at

    {
      type: "alert",
      message: toast_message,
      href: "/crm_transfers?status=failed"
    }
  end

  def toast_message
    count = unread_failed_scope.count
    noun = count == 1 ? "CRM transfer" : "CRM transfers"
    verb = count == 1 ? "failed" : "failed"

    "#{count} #{noun} #{verb}. Review #{count == 1 ? 'it' : 'them'} on CRM Transfers."
  end

  def durable_last_seen_at
    return unless user.respond_to?(:has_attribute?)
    return unless user.has_attribute?(:crm_transfers_last_seen_at)

    user[:crm_transfers_last_seen_at]
  end

  def latest_unread_failure_time
    @latest_unread_failure_time ||= parse_timestamp(latest_unread_failure_at)
  end

  def parse_timestamp(value)
    case value
    when ActiveSupport::TimeWithZone, Time, DateTime
      value.in_time_zone
    when String
      Time.zone.parse(value)
    end
  rescue ArgumentError
    nil
  end
endclass CrmTransferSignalsQuery
  include Rails.application.routes.url_helpers

  def initialize(user:, toast_seen_at:)
    @user = user
    @toast_seen_at = normalize_timestamp(toast_seen_at)
  end

  def call
    latest_unread_failure_at = unread_failed_scope.maximum(:created_at)
    unread_failed_count = unread_failed_scope.count

    {
      unread_failed_count: unread_failed_count,
      unread_retryable_count: unread_failed_scope.retryable.count,
      latest_unread_failure_at: latest_unread_failure_at&.iso8601,
      toast: build_toast(
        unread_failed_count: unread_failed_count,
        latest_unread_failure_at: latest_unread_failure_at
      )
    }
  end

  private

  attr_reader :user, :toast_seen_at

  def failed_scope
    @failed_scope ||= CrmTransfer
      .for_user(user)
      .within_retention_window
      .where(status: CrmTransfer::STATUS_FAILED)
  end

  def unread_failed_scope
    @unread_failed_scope ||= failed_scope.where(
      CrmTransfer.arel_table[:created_at].gt(user.crm_transfers_seen_at)
    )
  end

  def build_toast(unread_failed_count:, latest_unread_failure_at:)
    return nil if latest_unread_failure_at.blank?
    return nil if toast_seen_at.present? && toast_seen_at >= latest_unread_failure_at

    {
      type: 'alert',
      message: "#{unread_failed_count} CRM transfer#{'s' unless unread_failed_count == 1} failed. Review them on CRM Transfers.",
      href: crm_transfers_path(status: CrmTransfer::STATUS_FAILED)
    }
  end

  def normalize_timestamp(value)
    case value
    when ActiveSupport::TimeWithZone
      value
    when Time
      value.in_time_zone
    when String
      Time.zone.parse(value)
    end
  rescue ArgumentError, TypeError
    nil
  end
end