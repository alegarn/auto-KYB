class Client < ApplicationRecord
  belongs_to :user
  # If clients have dependent records (e.g., forms), ensure cleanup. Currently no direct associations.
  # has_many :forms, dependent: :destroy

  validates :name, presence: true
  validates :company_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A[+\d\-\s().]{6,}\z/ }, allow_blank: true

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :search_by_name_or_company, ->(query) {
    q = query.to_s.downcase
    where('lower(name) LIKE :q OR lower(company_name) LIKE :q', q: "%#{q}%")
  }
end
