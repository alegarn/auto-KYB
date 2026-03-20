class ClientsController < ApplicationController

  FILTER_ALL = "all"

  before_action :authorize_subscription
  before_action :set_client, only: %i[show edit update destroy export export_to_crm crm_match_suggestions crm_contact_details link_crm_contact create_crm_contact]

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
      uploaded_files: UploadedFileSerializer.collection(@client.uploaded_files.available),
      crm_connections: current_user.crm_connections.where(status: "active").as_json(only: [ :id, :provider ])
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

  def export_to_crm
    selected_providers = Array(params[:crms]).map(&:to_s).reject(&:blank?).uniq
    if selected_providers.empty?
      render json: { error: "No CRM selected" }, status: :unprocessable_entity
      return
    end

    connections = Crm::ConnectionManager.active_connections_for(current_user).where(provider: selected_providers)
    if connections.empty?
      render json: { error: "No active connections for selected CRMs" }, status: :unprocessable_entity
      return
    end

    Crm::DataExporter.new(@client).export_to_selected!(selected_providers)

    render json: {
      success: true,
      message: "Manual CRM export queued. Selected CRM transfers will run in the background and may take a moment to complete."
    }, status: :ok
  end

  def new
    render inertia: "Clients/New", props: default_inertia_props.merge(
      client: {},
      forms: forms_for_select,
      has_active_crm_connection: current_user.crm_connections.active.exists?
    )
  end

  def create
    client = current_user.clients.new(client_params)

    if client.save
      CrmSyncService.call(
        client,
        crm_sync_params[:strategy],
        external_contact_id: crm_sync_params[:external_contact_id],
        external_company_id: crm_sync_params[:external_company_id],
        sync_address_to_contact: crm_sync_params[:sync_address_to_contact],
        source: 'clients#create'
      )

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
    render inertia: "Clients/Edit", props: edit_inertia_props
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

    if result.action == :success
      # Handle CRM Sync if requested
      if crm_sync_params[:strategy].present? && crm_sync_params[:strategy] != "skip"
        CrmSyncService.call(
          @client,
          crm_sync_params[:strategy],
          external_contact_id: crm_sync_params[:external_contact_id],
          external_company_id: crm_sync_params[:external_company_id],
          sync_address_to_contact: crm_sync_params[:sync_address_to_contact],
          source: 'clients#update'
        )
      end

      sync_linked_client_profile_to_crm if crm_sync_params[:strategy].blank?

      redirect_to client_path(@client), notice: "Client updated"
      return
    end

    case result.action
    when :password_reveal
      store_client_form_one_time_password(result.client_form, result.password)
      redirect_to password_reveal_client_form_path(result.client_form), status: :see_other
    when :confirm_replace
      render inertia: "Clients/Edit", props: edit_inertia_props(
        confirm_replace_required: true,
        confirm_message: result.message,
        attempted_form_id: result.attempted_form_id
      ), status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render inertia: "Clients/Edit", props: edit_inertia_props(
      errors: e.record.errors.full_messages
    ), status: :unprocessable_entity
  end

  def destroy
    @client.destroy!
    # Provide a one-time Inertia flash so the frontend can show a toast
    flash.inertia[:toast] = { message: "Client deleted", type: "notice" }
    redirect_to clients_path, status: :see_other
  end




  def crm_match_suggestions
    connection = current_user.crm_connections.active.first
    if connection.nil? || @client.email.blank? || @client.crm_client_link.present?
      render json: { match: nil }
      return
    end

    service = Crm::ConnectionManager.service_for(connection)
    contact = service.search_contact_by_email(@client.email)

    render json: { match: contact }
  rescue => e
    Rails.logger.error("CRM Match Failed: #{e.message}")
    render json: { match: nil }
  end

  def crm_contact_details
    external_id = params[:external_contact_id] || @client.crm_client_link&.external_contact_id

    unless external_id
      render json: { error: "No external contact ID provided" }, status: :bad_request
      return
    end

    connection = current_user.crm_connections.active.first
    unless connection
      render json: { error: "No active CRM connection" }, status: :not_found
      return
    end

    service = Crm::ConnectionManager.service_for(connection)
    external_company_id = @client.crm_client_link&.external_company_id
    contact = service.fetch_contact(external_id)

    if contact && external_company_id.present?
      begin
        company = service.fetch_company(external_company_id)
        if company
          contact[:company_name] = company[:company_name] if company[:company_name].present?
          contact[:company_id]   = company[:company_id]   if company[:company_id].present?
          contact[:domain]       = company[:domain]        if company[:domain].present?
          contact[:phone]        = company[:phone]         if company[:phone].present?

          if company.dig(:address, :city).present? || company.dig(:address, :street).present? ||
             company.dig(:address, :postal_code).present?
            contact[:address] = company[:address]
          end
          contact[:country] = company[:country] if company[:country].present?
        end
      rescue => e
        Rails.logger.warn("Failed to fetch CRM company #{external_company_id}: #{e.message}")
      end
    end

    if contact
      render json: contact
    else
      render json: { error: "Contact not found in CRM" }, status: :not_found
    end
  rescue => e
    Rails.logger.error("CRM Details Failed: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end

  def link_crm_contact
    connection = current_user.crm_connections.active.first
    unless connection
      render json: { success: false, error: "No CRM connection" }, status: :unprocessable_entity
      return
    end

    external_id = params[:external_contact_id]

    if external_id.present?
      CrmClientLink.find_or_create_by!(
        client: @client,
        crm_connection: connection
      ) do |link|
        link.external_contact_id = external_id
      end
    end

    # Fetch and update client attributes from CRM if available
    begin
      service = Crm::ConnectionManager.service_for(connection)
      contact = service.fetch_contact(external_id)
      if contact
        @client.update!(
          name: contact[:name].presence || @client.name,
          email: contact[:email].presence || @client.email,
          phone: contact[:phone].presence || @client.phone,
          company_name: contact[:company_name].presence || @client.company_name,
          country: contact[:country].presence || @client.country,
          address: (@client.address || {}).merge(contact[:address] || {})
        )
      end
    rescue => e
      Rails.logger.error("Failed to update client from CRM during link: #{e.message}")
    end

    redirect_to edit_client_path(@client), notice: "Client linked to CRM and updated successfully."
  end

  def create_crm_contact
    CrmSyncService.call(@client, "create", source: 'clients#create_crm_contact')
    redirect_to edit_client_path(@client), notice: "CRM contact creation queued. Track progress in CRM Transfers."
  end

  private

  def authorize_subscription
    authorize :client, :index?
  end

  def client_params
    params.require(:client).permit(:name, :company_name, :company_id, :email, :phone, :country, address: %i[street city country postal_code])
  end

  def crm_sync_params
    params.fetch(:crm, {}).permit(:strategy, :external_contact_id, :external_company_id, :sync_address_to_contact)
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

  def edit_inertia_props(extra_props = {})
    {
      client: ClientSerializer.new(@client).as_json,
      forms: forms_for_select,
      current_form_id: @client.client_forms.order(created_at: :desc).first&.form_id,
      has_crm_link: @client.crm_client_link.present?,
      has_active_crm_connection: current_user.crm_connections.active.exists?,
      crm_sync_status: crm_sync_status_for(@client)
    }.merge(extra_props)
  end

  def render_form_not_found(view:, client:, include_user: false)
    props = if view == "Clients/Edit"
      edit_inertia_props(errors: { form_id: [ "Form not found" ] })
    else
      {
        client: client ? ClientSerializer.new(client).as_json : nil,
        errors: { form_id: [ "Form not found" ] },
        forms: forms_for_select
      }
    end

    props[:user] = user_props if include_user

    render inertia: view, props: props, status: :unprocessable_entity
  end

  def sync_linked_client_profile_to_crm
    Crm::ClientProfileSyncService.call(@client)
  end

  def crm_sync_status_for(client)
    link = client.crm_client_link
    connection = link&.crm_connection
    connection_active = connection&.status == "active"

    {
      linked: link.present?,
      connection_active: connection_active,
      auto_updates_on_edit: link.present? && connection_active,
      provider: connection&.provider,
      provider_name: crm_provider_name(connection&.provider)
    }
  end

  def crm_provider_name(provider)
    case provider
    when "hubspot"
      "HubSpot"
    when "salesforce"
      "Salesforce"
    when "zoho"
      "Zoho CRM"
    else
      provider&.humanize
    end
  end

end
