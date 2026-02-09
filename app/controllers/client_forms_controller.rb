class ClientFormsController < ApplicationController
  before_action :set_client_form, only: [:password_reveal, :export_responses]

  # POST /client_forms
  def create
    authorize_user!

    client = current_user.clients.find(params.dig(:client_form, :client_id))
    form = current_user.forms.find(params.dig(:client_form, :form_id))

    if client.client_forms.exists?
      redirect_to(client_path(client), alert: "Client already has a subspace") and return
      return
    end

    result = ClientInvitationService.create_invitation(client: client, form: form, expires_in: params.dig(:client_form, :expires_in) || 7.days)
    client_form = result[:client_form]
    password = result[:password]

    store_client_form_one_time_password(client_form, password)

    redirect_to password_reveal_client_form_path(client_form), status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to clients_path, alert: "Client or form not found"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to clients_path, alert: e.record.errors.full_messages.join(", ")
  end

  # GET /client_forms/:id/password_reveal
  def password_reveal
    entry = (session[:client_form_one_time_passwords] || {})[@client_form.id.to_s]

    if entry
      expires_at_val = entry[:expires_at] || entry['expires_at']
      if expires_at_val && Time.zone.parse(expires_at_val) > Time.current
        @password = entry[:password] || entry['password']
        # remove so it is shown only once
        session[:client_form_one_time_passwords].delete(@client_form.id.to_s)
      else
        @password = nil
        session[:client_form_one_time_passwords].delete(@client_form.id.to_s)
        flash.now[:alert] = "Password no longer available or expired."
      end
    else
      @password = nil
      flash.now[:alert] = "Password no longer available or expired."
    end

    render inertia: 'Clients/PasswordReveal', props: {
      client: { id: @client_form.client.id, name: @client_form.client.name },
      form: FormDetailSerializer.new(@client_form.form).as_json,
      access_url: client_portal_login_path(@client_form.access_token),
      password: @password
    }
  rescue ActiveRecord::RecordNotFound
    redirect_to clients_path, alert: 'Link not found'
  end

  # GET /client_forms/:id/export_responses(.csv)
  def export_responses
    authorize_user!

    respond_to do |format|
      format.csv do
        csv_data = FormResponseExportService.call(@client_form)

        send_data csv_data,
                  filename: "form-responses-#{@client_form.id}-#{Date.current}.csv",
                  type: 'text/csv; charset=utf-8',
                  disposition: 'attachment'
        return
      end

      format.json do
        render json: FormResponseExportService.to_json(@client_form)
      end

      format.any { head :not_acceptable }
    end
  end

  private

  def authorize_user!
    return if current_user
    redirect_to(sign_in_path) and return
  end

  def set_client_form
    @client_form = ClientForm.includes(:form, :form_responses, :client).find(params[:id])

    # ensure the current_user owns the underlying client
    if current_user && @client_form.client.user_id != current_user.id
      redirect_to(clients_path, alert: "You don't have permission to access this form") and return
    end
  end
end
