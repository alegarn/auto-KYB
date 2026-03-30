class User < ApplicationRecord

  has_secure_password

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  generates_token_for :signin, expires_in: 10.minutes do
    email
  end


  has_many :sessions, dependent: :destroy
  has_many :forms, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :crm_connections, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :provider, presence: true, if: -> { uid.present? }
  validates :uid, presence: true, if: -> { provider.present? }
  validates :uid, uniqueness: { scope: :provider }, allow_blank: true

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  before_validation :assign_random_password, on: :create, if: -> { password.blank? }

  after_create :initialize_default_forms

  # Subscription statuses from Stripe / application state
  enum :plan, {
    basic: "basic",
    pro: "pro"
  }

  def crm_plan_eligible?
    pro?
  end

  enum :subscription_status, {
    incomplete: 'incomplete',
    trialing:   'trialing',
    active:     'active',
    past_due:   'past_due',
    canceled:   'canceled',
    unpaid:     'unpaid'
  }

  # Returns true when the user has an active or trialing subscription
  def subscribed?
    active? || trialing?
  end

  # Returns true when subscription is active and not expired
  # subscription_ends_at may be nil for non-expiring subscriptions
  def active_subscription?
    return false unless active?
    return true if subscription_ends_at.nil?

    subscription_ends_at > Time.current
  end

  # Returns true when the user is currently on a trial
  def on_trial?
    trialing?
  end

  def eligible_for_sign_in?
    return true if active? || trialing?

    canceled_within_retention_window?
  end

  def canceled_within_retention_window?
    canceled? && subscription_canceled_at.present? && subscription_canceled_at > 1.year.ago
  end

  def crm_transfers_seen_at
    return Time.at(0).in_time_zone unless has_attribute?(:crm_transfers_last_seen_at)

    self[:crm_transfers_last_seen_at] || Time.at(0).in_time_zone
  end

  private

  def assign_random_password
    self.password = self.password_confirmation = SecureRandom.base58(24)
  end

  def initialize_default_forms
    FormService.initialize_default_for_user(self)
  rescue => e
    Rails.logger.error("User: failed to initialize default forms for user=#{id} - #{e.message}")
  end

end
