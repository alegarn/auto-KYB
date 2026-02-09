class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy export]

  def index
    return render inertia: 'Clients/Index', props: { user: nil, clients: [], session_id: current_session_id } unless current_user

    scope = Client.by_user(current_user.id).order(created_at: :desc)
    scope = scope.search_by_name_or_company(params[:q]) if params[:q].present?

    # Filter by client form status if provided (ignore "All")
    if params[:status].present? && params[:status].to_s.downcase != 'all'
      scope = scope.where(form_status: params[:status])
    end

    @pagy, clients_page = pagy(scope, limit: 10, page: params[:page])
    clients = clients_page.map { |c| ClientSerializer.new(c).as_json }

    render inertia: 'Clients/Index', props: {
      user: user_props,
      session_id: current_session_id,
      clients: clients,
      meta: {
        page: @pagy.page,
        per_page: (@pagy.limit || clients_page.size),
        total_count: scope.count
      }
    }
  end

  def show
    client_form = @client.client_forms.includes(:form).order(created_at: :desc).first

    render inertia: 'Clients/Show', props: {
      user: user_props,
      session_id: current_session_id,
      client: ClientSerializer.new(@client).as_json,
      client_form: client_form ? {
        id: client_form.id,
        status: ClientForm.statuses.key(client_form.status) || client_form.status,
        created_at: client_form.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
        form: FormSerializer.new(client_form.form).as_json
      } : nil,
      forms: forms_props
    }
  end

  # GDPR export endpoint - returns JSON or CSV representation of the client
  def export
    respond_to do |format|
      format.json { render json: ClientSerializer.new(@client).as_json }

      format.csv do
        # re-query selecting only the attributes we want to return (exclude id)
        client_for_export = current_user.clients
                             .where(id: @client.id)
                             .select(:name, :company_name, :email, :phone, :address, :created_at, :updated_at)
                             .first!

        csv_data = ClientExportService.call(client_for_export)

        send_data csv_data, filename: "client-#{@client.id}.csv", type: 'text/csv'
      end

      # fallback for non-explicit formats
      format.any { render json: ClientSerializer.new(@client).as_json }
    end
  end

  def new
    render inertia: 'Clients/New', props: {
      user: user_props,
      session_id: current_session_id,
      client: {},
      forms: forms_props
    }
  end

  def create
    client = current_user.clients.new(client_params)

    if client.save
      form_id = client_form_params[:form_id]

      if form_id.present?
        form = current_user.forms.find(form_id)

        result = ClientInvitationService.create_invitation(client: client, form: form, expires_in: client_form_params[:expires_in] || 7.days)
        client_form = result[:client_form]
        password = result[:password]

        store_client_form_one_time_password(client_form, password)
        redirect_to password_reveal_client_form_path(client_form), status: :see_other
        return
      end

      redirect_to clients_path, status: :see_other
    else
      render inertia: 'Clients/New', props: {
        user: user_props,
        session_id: current_session_id,
        client: ClientSerializer.new(client).as_json,
        errors: client.errors.messages,
        forms: forms_props
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render_form_not_found(view: 'Clients/New', client: client, include_user: true)
  end

  def edit
    render inertia: 'Clients/Edit', props: {
      session_id: current_session_id,
      client: ClientSerializer.new(@client).as_json,
      forms: forms_props,
      current_form_id: @client.client_forms.order(created_at: :desc).first&.form_id
    }
  end

  def update
    new_form_id = client_form_params[:form_id]

    if new_form_id.present?
      begin
        new_form = current_user.forms.find(new_form_id)
      rescue ActiveRecord::RecordNotFound
        render_form_not_found(view: 'Clients/Edit', client: @client)
        return
      end
    end

    confirm_replace_exception = nil

    ActiveRecord::Base.transaction do
      @client.update!(client_params)

      if new_form_id.present?
        begin
          result = ClientFormRemapperService.call(
            client: @client,
            new_form: new_form,
            confirm_replace: ActiveRecord::Type::Boolean.new.cast(client_form_params[:confirm_replace]),
            expires_in: client_form_params[:expires_in] || 7.days
          )

          if result[:status] == :created
            client_form = result[:client_form]
            password = result[:password]
            store_client_form_one_time_password(client_form, password)
            redirect_to password_reveal_client_form_path(client_form), status: :see_other
            return
          end
        rescue ClientFormRemapperService::ConfirmReplaceRequired => e
          confirm_replace_exception = e
          raise ActiveRecord::Rollback
        end
      end
    end

    if confirm_replace_exception
      render inertia: 'Clients/Edit', props: {
        session_id: current_session_id,
        client: ClientSerializer.new(@client).as_json,
        confirm_replace_required: true,
        confirm_message: confirm_replace_exception.message,
        forms: forms_props,
        attempted_form_id: confirm_replace_exception.attempted_form_id
      }, status: :unprocessable_entity
      return
    end

    redirect_to client_path(@client), notice: 'Client updated'
  rescue ActiveRecord::RecordInvalid => e
    render inertia: 'Clients/Edit', props: {
      session_id: current_session_id,
      client: @client.present? ? ClientSerializer.new(@client).as_json : nil,
      errors: e.record.errors.full_messages,
      forms: forms_props
    }, status: :unprocessable_entity
  end

  def destroy
    @client.destroy!

    redirect_to clients_path, notice: 'Client deleted', status: :see_other
  end

  private

  def client_params
    params.require(:client).permit(:name, :company_name, :email, :phone, address: {})
  end

  def set_client
    @client = current_user.clients.find(params[:id])
  end

  def user_props
    current_user ? { id: current_user.id, email: current_user.email } : nil
  end

  def forms_props
    return [] unless current_user

    FormSerializer.collection(current_user.forms.order(created_at: :desc))
  end

  def client_form_params
    params.fetch(:client_form, {}).permit(:form_id, :confirm_replace, :expires_in)
  end

  def render_form_not_found(view:, client:, include_user: false)
    props = {
      session_id: current_session_id,
      client: client.present? ? ClientSerializer.new(client).as_json : nil,
      errors: { form_id: ["Form not found"] },
      forms: forms_props
    }

    props[:user] = user_props if include_user

    render inertia: view, props: props, status: :unprocessable_entity
  end
end
