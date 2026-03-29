class FormsController < ApplicationController

  before_action :authorize_subscription

  def index
    forms = current_user ? FormSerializer.collection(current_user.forms.order(created_at: :desc)) : []

    render inertia: "forms/index", props: default_inertia_props.merge(
      forms: forms,
      active_form_ids: InertiaRails.defer { active_form_ids }
    )
  end

  def show
    form = current_user.forms.find(params[:id])
    detail = FormDetailSerializer.new(form).as_json
    respond_to do |format|
      format.json { render json: detail, status: :ok }
      format.html { render inertia: "forms/show", props: default_inertia_props.merge(form: detail) }
    end
  end

  def new
    render inertia: "forms/new", props: form_editor_props
  end

  def create
    FormService.create_form(current_user, form_params.to_h)
    redirect_to forms_path, status: :see_other
  rescue FormService::DuplicateExportKeysError => e
    error_messages = [ "Export mapping keys must be unique. Duplicate keys: #{e.duplicate_keys.join(', ')}" ]
    if request.format.json?
      render json: { errors: error_messages }, status: :unprocessable_entity
    else
      render inertia: "forms/new", props: form_editor_props(
        errors: error_messages
      ), status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render inertia: "forms/new", props: form_editor_props(
      errors: e.record.errors.full_messages
    ), status: :unprocessable_entity
  end

  def edit
    form = current_user.forms.find(params[:id])

    render inertia: "forms/edit", props: form_editor_props(
      form: FormDetailSerializer.new(form).as_json
    )
  end

  def destroy
    form = current_user.forms.find(params[:id])
    form.destroy!
    respond_to do |format|
      format.json { head :no_content }
      format.html do
        redirect_to forms_path, flash: { inertia: { toast: { message: "Form deleted", type: "notice" } } }, status: :see_other
      end
    end
  end

  def test_crm_mapping
    form = current_user.forms.find(params[:id])
    form_fields = params[:fields] || form.structure&.dig("fields") || []

    connections = Crm::ConnectionManager.active_connections_for(current_user)
    if connections.empty?
      render json: { error: "No active CRM connections found." }, status: :unprocessable_entity
      return
    end

    dummy_client = build_dummy_client
    all_crm_props = crm_properties # Hash like { hubspot: { contact: [...], company: [...] } }

    success = true
    errors = []

    connections.each do |conn|
      service = Crm::ConnectionManager.service_for(conn)

      result = Crm::TestPayloadBuilder.build(
        fields:         form_fields,
        crm_properties: all_crm_props,
        provider:       conn.provider
      )

      # Optional but recommended, pass field_metadata to export if supported
      export_kwargs = { company_data: result[:company] }
      export_kwargs[:field_metadata] = result[:field_metadata]

      export_result = service.export_data(
        dummy_client,
        result[:contact],
        [],
        **export_kwargs
      )

      unless export_result[:success]
        success = false
        errors << "#{conn.provider.titleize}: #{export_result[:error]}"
      end
    end

    if success
      render json: { success: true }, status: :ok
    else
      render json: { error: errors.join(", ") }, status: :unprocessable_entity
    end
  end

def duplicate
    form = current_user.forms.find(params[:id])
    FormService.duplicate_form(current_user, form)

    respond_to do |format|
      format.html do
        redirect_to forms_path, flash: {
          inertia: {
            toast: {
              message: "Form duplicated successfully",
              type: "notice"
            }
          }
        }, status: :see_other
      end
    end
  end

  def update
    form = current_user.forms.find(params[:id])
    
    # Store the parameters locally so we can mutate them
    current_params = form_params.to_h

    # Check for requested custom CRM properties
    custom_mappings = []
    (current_params.dig(:structure, :fields) || current_params.dig("structure", "fields") || []).each do |f|
      crm_mapping = (f[:metadata] || f["metadata"])&.dig("crm_mapping") || {}
      crm_mapping.each do |provider, mapping|
        if mapping["type"] == "custom"
          # Generate a safe property name if blank
          raw_prop_name = mapping["property_name"].presence
          # Strip compound key prefix if present, then fall back to label
          raw_prop_name = Crm::KeyParser.property_name(raw_prop_name) if raw_prop_name.present? && Crm::KeyParser.compound?(raw_prop_name)
          prop_name = raw_prop_name.presence || (f["label"] || f[:label]).to_s.downcase.gsub(/[^a-z0-9_]/, "_")
          obj_type = mapping["object_type"] || "contact"
          # Store compound key as property_name for disambiguation
          mapping["property_name"] = Crm::KeyParser.build(obj_type, prop_name)
          custom_mappings << { 
            provider: provider, 
            label: (f["label"] || f[:label]), 
            property_name: prop_name,
            object_type: obj_type,
            field_type: (f["field_type"] || f[:field_type]).to_s,
            options: f["options"] || f[:options] || [],
            allow_multiple: f["allow_multiple"] || f[:allow_multiple]
          }
        end
      end
    end

    # Call update_form exactly once with the potentially mutated parameters
    FormService.update_form(current_user, form, current_params)

    if custom_mappings.any?
      CrmPropertyCreationJob.perform_later(current_user.id, custom_mappings)
    end

    respond_to do |format|
      format.json { render json: FormDetailSerializer.new(form).as_json, status: :ok }
      format.html do
        redirect_to edit_form_path(form), flash: {
          inertia: {
          toast: {
            message: "Form edited",
            type: "notice"
          }
        }
      }, status: :see_other
    end
  end

  rescue FormService::DataLossWarning
    redirect_to edit_form_path(form), flash: {
      inertia: {
        toast: {
          message: "You can update the form, but the form responses will be erased",
          type: "alert"
        }
      }
    }, status: :see_other
  rescue FormService::DuplicateExportKeysError => e
    error_messages = [ "Export mapping keys must be unique. Duplicate keys: #{e.duplicate_keys.join(', ')}" ]
    if request.format.json?
      render json: { errors: error_messages }, status: :unprocessable_entity
    else
      render inertia: "forms/edit", props: form_editor_props(
        form: form ? FormDetailSerializer.new(form).as_json : nil,
        errors: error_messages
      ), status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render inertia: "forms/edit", props: form_editor_props(
      form: form ? FormDetailSerializer.new(form).as_json : nil,
      errors: e.record.errors.full_messages
    ), status: :unprocessable_entity
  end

  private

  def build_dummy_client
    Struct.new(:name, :email, :company_name, :phone, :address, :country, :company_id, :crm_client_link).new(
      "Test Client",
      "test_crm_#{SecureRandom.hex(4)}@example.com",
      "Test Company #{SecureRandom.hex(2)}",
      "+33123456789",
      "123 Test Street",
      "FR",
      "TC-#{SecureRandom.hex(4)}",
      nil # Force create in service since it's a test
    )
  end

  def authorize_subscription
    authorize :form, :index?
  end

  def active_form_ids
    return [] unless current_user

    form_ids = current_user.forms.select(:id)
    ClientForm.joins(:form_responses)
              .where(form_id: form_ids)
              .distinct
              .pluck(:form_id)
  end

  def crm_properties
    connections = Crm::ConnectionManager.active_connections_for(current_user)
    properties = {}

    if connections.any? { |c| c.provider == "hubspot" }
      begin
        service = Crm::Hubspot::PropertiesService.new(current_user)
        properties[:hubspot] = {
          contact: service.list_properties(object_type: 'contact'),
          company: service.list_properties(object_type: 'company')
        }
      rescue StandardError => e
        Rails.logger.error("[FormsController#crm_properties] #{e.message}")
        properties[:hubspot] = { contact: [], company: [] }
      end
    end

    properties
  end

  def active_crm_providers
    return [] unless current_user.can_use_crm?
    current_user.crm_connections.active.distinct.pluck(:provider)
  end

  def form_editor_props(extra_props = {})
    default_inertia_props.merge(
      activeCrmProviders: active_crm_providers,
      crmProperties: InertiaRails.defer { crm_properties }
    ).merge(extra_props)
  end

  def form_params
    params.require(:form).permit(
      :name,
      :description,
      structure: {
        settings: {},
        fields: [ :id, :label, :field_type, :required, :position, :allow_multiple, { options: [] }, { metadata: {} } ]
      }
    )
  end

end
