class ClientFormsController < ApplicationController
  # POST /client_forms
  def create
    authorize_user!

    client = current_user.clients.find(params.dig(:client_form, :client_id))
    form = current_user.forms.find(params.dig(:client_form, :form_id))

    result = ClientInvitationService.create_invitation(client: client, form: form, expires_in: params.dig(:client_form, :expires_in) || 7.days)
    client_form = result[:client_form]
    password = result[:password]

    session[:client_form_one_time_passwords] ||= {}
    session[:client_form_one_time_passwords][client_form.id.to_s] = {
      password: password,
      expires_at: 5.minutes.from_now.iso8601
    }

    redirect_to password_reveal_client_form_path(client_form), status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to clients_path, alert: "Client or form not found"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to clients_path, alert: e.record.errors.full_messages.join(", ")
  end

  # GET /client_forms/:id/password_reveal
  def password_reveal
    client_form = ClientForm.find(params[:id])
    entry = (session[:client_form_one_time_passwords] || {})[client_form.id.to_s]

    if entry
      expires_at_val = entry[:expires_at] || entry['expires_at']
      if expires_at_val && Time.zone.parse(expires_at_val) > Time.current
        @password = entry[:password] || entry['password']
        # remove so it is shown only once
        session[:client_form_one_time_passwords].delete(client_form.id.to_s)
      else
        @password = nil
        session[:client_form_one_time_passwords].delete(client_form.id.to_s)
        flash.now[:alert] = "Password no longer available or expired."
      end
    else
      @password = nil
      flash.now[:alert] = "Password no longer available or expired."
    end

    render inertia: 'Clients/PasswordReveal', props: {
      client: { id: client_form.client.id, name: client_form.client.name },
      form: FormDetailSerializer.new(client_form.form).as_json,
      access_url: client_portal_login_path(client_form.access_token),
      password: @password
    }
  rescue ActiveRecord::RecordNotFound
    redirect_to clients_path, alert: 'Link not found'
  end

  private

  def authorize_user!
    redirect_to sign_in_path unless current_user
  end
end
