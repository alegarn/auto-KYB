class ClientForm < ApplicationRecord
  belongs_to :client
  belongs_to :form
  has_secure_password validations: false
  has_secure_token :access_token

  STATUSES = { 'draft' => 0, 'filled' => 1, 'validated' => 2 }.freeze

  def self.statuses
    STATUSES
  end

  before_validation :normalize_status

  validates :client, presence: true
  validates :form, presence: true

  def locked?
    validated_at.present? || (expires_at.present? && expires_at.past?)
  end

  def validate!
    update!(status: self.class.statuses['validated'], validated_at: Time.current)
  end

  private

  def normalize_status
    if status.is_a?(Symbol) || status.is_a?(String)
      self[:status] = self.class.statuses[status.to_s]
    end
  end
end
