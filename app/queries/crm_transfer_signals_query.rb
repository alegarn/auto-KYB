class CrmTransferSignalsQuery

  def initialize(user:, toast_seen_at:)
    @user = user
    @toast_seen_at = normalize_timestamp(toast_seen_at)
  end

  def call
    latest_unread_failure_at = unread_failed_scope.maximum(:created_at)

    {
      unread_failed_count: unread_failed_count,
      unread_retryable_count: unread_retryable_count,
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
      CrmTransfer.arel_table[:created_at].gt(durable_last_seen_at)
    )
  end

  def unread_failed_count
    @unread_failed_count ||= unread_failed_scope.count
  end

  def unread_retryable_count
    @unread_retryable_count ||= unread_failed_scope.retryable.count
  end

  def build_toast(unread_failed_count:, latest_unread_failure_at:)
    return nil if unread_failed_count.zero?
    return nil if latest_unread_failure_at.blank?
    return nil if toast_seen_at.present? && toast_seen_at >= latest_unread_failure_at

    {
      type: 'alert',
      message: toast_message(unread_failed_count),
      href: '/crm_transfers?status=failed'
    }
  end

  def toast_message(unread_failed_count)
    item_pronoun = unread_failed_count == 1 ? 'it' : 'them'
    transfer_noun = unread_failed_count == 1 ? 'CRM transfer' : 'CRM transfers'

    "#{unread_failed_count} #{transfer_noun} failed. Review #{item_pronoun} on CRM Transfers."
  end

  def durable_last_seen_at
    return user.crm_transfers_seen_at if user.respond_to?(:crm_transfers_seen_at)

    Time.at(0).in_time_zone
  end

  def normalize_timestamp(value)
    case value
    when ActiveSupport::TimeWithZone
      value
    when Time, DateTime
      value.in_time_zone
    when String
      Time.zone.parse(value)
    end
  rescue ArgumentError, TypeError
    nil
  end

end
