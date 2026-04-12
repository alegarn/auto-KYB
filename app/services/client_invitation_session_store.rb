class ClientInvitationSessionStore

  EXPIRY_DURATION = 5.minutes

  def initialize(session)
    @session = session
  end

  def store(client_form_id:, password:, expires_in: EXPIRY_DURATION)
    @session[:client_form_one_time_passwords] ||= {}
    @session[:client_form_one_time_passwords][client_form_id.to_s] = {
      "password" => password,
      "expires_at" => expires_in.from_now.iso8601,
      "decision_pending" => true
    }
  end

  def fetch_live(client_form_id)
    entry = raw_entry(client_form_id)
    return nil unless entry
    return nil if expired?(entry)

    entry
  end

  def decision_pending?(client_form_id)
    entry = fetch_live(client_form_id)
    return false unless entry

    entry["decision_pending"]
  end

  def complete_decision(client_form_id)
    entry = raw_entry(client_form_id)
    return unless entry

    entry["decision_pending"] = false
  end

  def consume_password(client_form_id)
    entry = raw_entry(client_form_id)
    return nil unless entry

    if expired?(entry)
      delete_entry(client_form_id)
      return nil
    end

    password = entry["password"]
    delete_entry(client_form_id)
    password
  end

  def live_password(client_form_id)
    entry = fetch_live(client_form_id)
    return nil unless entry

    entry["password"]
  end

  private

  def raw_entry(client_form_id)
    (@session[:client_form_one_time_passwords] || {})[client_form_id.to_s]
  end

  def expired?(entry)
    expires_at_val = entry["expires_at"]
    return true unless expires_at_val

    Time.zone.parse(expires_at_val) <= Time.current
  end

  def delete_entry(client_form_id)
    @session[:client_form_one_time_passwords]&.delete(client_form_id.to_s)
  end

end
