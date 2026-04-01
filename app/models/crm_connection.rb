class CrmConnection < ApplicationRecord

  belongs_to :user
  has_many :crm_transfers, dependent: :destroy
  has_many :crm_client_links, dependent: :destroy

  PROVIDERS = %w[hubspot salesforce zoho].freeze

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider, uniqueness: { scope: :user_id, message: "connection already exists" }
  validates :status, presence: true

  encrypts :access_token
  encrypts :refresh_token

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def token_expired?
    expires_at.present? && expires_at < Time.current
  end

  def token_expires_soon?(buffer: 5.minutes)
    expires_at.present? && expires_at < (Time.current + buffer)
  end

end
