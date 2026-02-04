class ClientInvitationService
  # Creates a ClientForm for a client & form, generates an access token and one-time password.
  # Returns a hash: { client_form: ClientForm, password: String }
  def self.create_invitation(client:, form:, expires_in: 7.days)
    # ensure status saved as integer to satisfy NOT NULL constraint
    status_value = ClientForm.statuses['draft']
    client_form = ClientForm.create!(client: client, form: form, status: status_value, expires_at: Time.current + expires_in)

    # generate a random, human-friendly one-time password
    password = SecureRandom.base58(12)

    # set password (requires has_secure_password on ClientForm)
    if client_form.respond_to?(:password=)
      client_form.password = password
    else
      client_form.password_digest = BCrypt::Password.create(password)
    end

    # ensure access_token exists
    if client_form.respond_to?(:regenerate_access_token)
      client_form.regenerate_access_token
    else
      client_form.access_token ||= SecureRandom.hex(16)
    end

    client_form.save!

    { client_form: client_form, password: password }
  end
end
