class FormField < ApplicationRecord
  belongs_to :form

  validates :label, presence: true
  validates :field_type, presence: true, inclusion: { in: %w[text number date email textarea checkbox select radio] }

  scope :ordered, -> { order(:position) }
end
