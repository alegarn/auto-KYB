class Client < ApplicationRecord

  belongs_to :user
  has_many :client_forms, dependent: :destroy
  has_many :form_responses, through: :client_forms
  # If clients have dependent records (e.g., forms), ensure cleanup. Currently no direct associations.
  # has_many :forms, dependent: :destroy

  validates :name, presence: true
  validates :company_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A[+\d\-\s().]{6,}\z/ }, allow_blank: true

  enum :form_status, { inactive: 0, linked: 1, active: 2, validated: 3 }

  before_validation :ensure_form_status

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :search_by_name_or_company, ->(query) {
    q = query.to_s.downcase
    where("lower(name) LIKE :q OR lower(company_name) LIKE :q", q: "%#{q}%")
  }
  scope :for_export, -> { select(:name, :company_name, :company_id, :country, :email, :phone, :address, :created_at, :updated_at) }

  private

  def ensure_form_status
    self.form_status = :inactive if form_status.nil?
  end

  # New attributes: company identifier (string) and top-level country
  # company_id is a plain string (no companies table in this app)
  validates :company_id, length: { maximum: 255 }, allow_blank: true
  validates :country, length: { maximum: 100 }, allow_blank: true

end
