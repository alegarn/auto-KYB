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

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  before_validation :assign_random_password, on: :create, if: -> { password.blank? }

  after_create :initialize_default_forms

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
