class ClientsController < ApplicationController

  FILTER_ALL = "all"

  before_action :set_client, only: %i[show edit update destroy export]

  def index
    scope = Client.by_user(current_user.id).order(created_at: :desc)
    scope = scope.search_by_name_or_company(params[:q]) if params[:q].present?

    if params[:status].present? && params[:status].to_s.downcase != FILTER_ALL
      scope = scope.where(form_status: params[:status])
    end

    @pagy, clients_page = pagy(scope, limit: 10, page: params[:page])

    render inertia: "Clients/Index", props: default_inertia_props.merge(
      clients: ClientSerializer.collection(clients_page),
      meta: {
        page: @pagy.page,
        per_page: @pagy.limit,
        total_count: @pagy.count
      }
    )
  end

  def show
    client_form = @client.client_forms.includes(:form).order(created_at: :desc).first

    render inertia: "Clients/Show", props: default_inertia_props.merge(
      client: ClientSerializer.new(@client).as_json,
      client_form: ClientFormSerializer.new(client_form).as_json,
      forms: forms_for_select,
      file_retention: FileRetentionPolicy.as_json,
      uploaded_files: UploadedFileSerializer.collection(@client.uploaded_files.available)
    )
  end

  def export
    respond_to do |format|
      format.json do
        json_data = ClientSerializer.new(@client).to_json
        send_data json_data, filename: "client-#{@client.id}.json", type: "application/json", disposition: "attachment"
      end

      format.csv do
        client_for_export = current_user.clients.where(id: @client.id).for_export.first!
        csv_data = ClientExportService.call(client_for_export)
        send_data csv_data, filename: "client-#{@client.id}.csv", type: "text/csv", disposition: "attachment"
      end

      format.any { render json: ClientSerializer.new(@client).as_json }
    end
  end

  def new
    render inertia: "Clients/New", props: default_inertia_props.merge(
      client: {},
      forms: forms_for_select
    )
  end

  def create
    client = current_user.clients.new(client_params)

    if client.save
      form_id = client_form_params[:form_id]

      if form_id.present?
        form = find_form_for_user(form_id)
        unless form
          render_form_not_found(view: "Clients/New", client: client, include_user: true)
          return
        end

        result = ClientInvitationService.create_invitation(
          client: client,
          form: form,
          expires_in: client_form_params[:expires_in] || 7.days
        )

        store_client_form_one_time_password(result[:client_form], result[:password])
        redirect_to password_reveal_client_form_path(result[:client_form]), status: :see_other
        return
      end

      redirect_to clients_path, status: :see_other
    else
      render inertia: "Clients/New", props: default_inertia_props.merge(
        client: ClientSerializer.new(client).as_json,
        errors: client.errors.messages,
        forms: forms_for_select
      ), status: :unprocessable_entity
    end
  end

  def edit
    render inertia: "Clients/Edit", props: {
      client: ClientSerializer.new(@client).as_json,
      forms: forms_for_select,
      current_form_id: @client.client_forms.order(created_at: :desc).first&.form_id
    }
  end

  def update
    new_form_id = client_form_params[:form_id]

    if new_form_id.present?
      new_form = find_form_for_user(new_form_id)
      unless new_form
        render_form_not_found(view: "Clients/Edit", client: @client)
        return
      end
    end

    result = ClientUpdateService.call(
      client: @client,
      client_params: client_params,
      new_form: new_form,
      confirm_replace: ActiveRecord::Type::Boolean.new.cast(client_form_params[:confirm_replace]),
      expires_in: client_form_params[:expires_in] || 7.days
    )

    case result.action
    when :password_reveal
      store_client_form_one_time_password(result.client_form, result.password)
      redirect_to password_reveal_client_form_path(result.client_form), status: :see_other
    when :confirm_replace
      render inertia: "Clients/Edit", props: {
        client: ClientSerializer.new(@client).as_json,
        confirm_replace_required: true,
        confirm_message: result.message,
        forms: forms_for_select,
        attempted_form_id: result.attempted_form_id
      }, status: :unprocessable_entity
    when :success
      redirect_to client_path(@client), notice: "Client updated"
    end
  rescue ActiveRecord::RecordInvalid => e
    render inertia: "Clients/Edit", props: {
      client: ClientSerializer.new(@client).as_json,
      errors: e.record.errors.full_messages,
      forms: forms_for_select
    }, status: :unprocessable_entity
  end

  def destroy
    @client.destroy!
    # Provide a one-time Inertia flash so the frontend can show a toast
    flash.inertia[:toast] = { message: "Client deleted", type: "notice" }
    redirect_to clients_path, status: :see_other
  end

  private

  def client_params
    params.require(:client).permit(:name, :company_name, :company_id, :email, :phone, :country, address: %i[street city country postal_code])
  end

  def client_form_params
    params.fetch(:client_form, {}).permit(:form_id, :confirm_replace, :expires_in)
  end

  def set_client
    @client = current_user.clients.find(params[:id])
  end

  def forms_for_select
    return [] unless current_user

    FormSerializer.collection(current_user.forms.order(created_at: :desc))
  end

  def find_form_for_user(form_id)
    current_user.forms.find_by(id: form_id)
  end

  def render_form_not_found(view:, client:, include_user: false)
    props = {
      client: client ? ClientSerializer.new(client).as_json : nil,
      errors: { form_id: [ "Form not found" ] },
      forms: forms_for_select
    }

    props[:user] = user_props if include_user

    render inertia: view, props: props, status: :unprocessable_entity
  end

end
