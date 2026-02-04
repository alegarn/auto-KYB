class Form < ApplicationRecord
  belongs_to :user
  has_many :form_fields, dependent: :destroy
  has_many :client_forms, dependent: :destroy
  has_many :form_responses, through: :client_forms

  validates :name, presence: true

  # Serialized structure stored in JSONB
  def fields
    form_fields.order(:position)
  end
end
