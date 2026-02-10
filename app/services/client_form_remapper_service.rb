class ClientFormRemapperService

  class ConfirmReplaceRequired < StandardError

    attr_reader :attempted_form_id

    def initialize(attempted_form_id, message = nil)
      @attempted_form_id = attempted_form_id
      super(message || "Changing the active form will delete existing form responses. Confirm to proceed.")
    end

  end

  # Performs the remap: deletes old responses and creates a new ClientForm invitation.
  # Raises ConfirmReplaceRequired when the client is active and has responses and no confirmation was provided.
  # Returns a hash with :client_form and :password when a new invitation was created, or :no_change.
  def self.call(client:, new_form:, confirm_replace: false, expires_in: 7.days)
    current_cf = client.client_forms.includes(:form_responses).order(created_at: :desc).first

    return { status: :no_change } if current_cf && current_cf.form_id == new_form.id

    if client.active? && current_cf&.form_responses&.exists? && !confirm_replace
      raise ConfirmReplaceRequired.new(new_form.id)
    end

    client.transaction do
      # Revoke previous client portal immediately so old tokens are rejected.
      if current_cf
        current_cf.update!(access_token: nil, expires_at: Time.current - 1.second)
      end

      # Hard-delete previous form responses as requested (skip callbacks)
      current_cf&.form_responses&.delete_all

      # Create invitation (this will create a new ClientForm)
      result = ClientInvitationService.create_invitation(client: client, form: new_form, expires_in: expires_in)

      client.update!(form_status: :linked) unless client.linked?

      { status: :created, client_form: result[:client_form], password: result[:password] }
    end
  end

end
