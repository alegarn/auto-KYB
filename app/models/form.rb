class Form < ApplicationRecord
  belongs_to :user
  has_many :form_fields, dependent: :destroy

  validates :name, presence: true

  # Serialized structure stored in JSONB
  def fields
    form_fields.order(:position)
  end
end
