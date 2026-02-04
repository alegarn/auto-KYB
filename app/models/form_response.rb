class FormResponse < ApplicationRecord
  belongs_to :client_form

  validates :client_form, presence: true

  before_create :set_version

  private

  def set_version
    max = FormResponse.where(client_form_id: client_form_id).maximum(:version) || 0
    self.version = max + 1
  end
end
