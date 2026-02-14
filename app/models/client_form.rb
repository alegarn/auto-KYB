class ClientForm < ApplicationRecord

  belongs_to :client
  belongs_to :form
  has_many :form_responses, dependent: :destroy
  has_secure_password validations: false
  has_secure_token :access_token

  STATUSES = { "draft" => 0, "filled" => 1, "validated" => 2 }.freeze

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
    update!(status: self.class.statuses["validated"], validated_at: Time.current)
  end

  # Save a form response for this client_form. Creates a new FormResponse
  # and transitions status from draft -> filled on first save. If `validate`
  # is true the client_form is validated (locked) after the save.
  def save_response!(data: {}, validate: false)
    raise ActiveRecord::RecordInvalid.new(self) if locked?

    # Keep only the latest response: remove any existing responses
    # (versioning previously incremented `version` per response; see
    # commented code in FormResponse model).
    response = nil
    transaction do
      old_response_ids = form_responses.pluck(:id)
      available_files = UploadedFile.where(form_response_id: old_response_ids).available
      available_files.update_all(form_response_id: nil)

      form_responses.delete_all
      response = FormResponse.create!(client_form: self, data: data)

      UploadedFile.where(client_id: client_id, form_response_id: nil)
                  .available
                  .update_all(form_response_id: response.id)
    end

    if self.status == self.class.statuses["draft"] && FormResponse.where(client_form_id: id).count > 0
      update!(status: self.class.statuses["filled"])
    end

    if validate
      validate!
    end

    client.update!(form_status: validate ? :validated : :active)

    response
  end

  private

  def normalize_status
    if status.is_a?(Symbol) || status.is_a?(String)
      self[:status] = self.class.statuses[status.to_s]
    end
  end

end
