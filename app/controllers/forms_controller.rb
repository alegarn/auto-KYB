class FormsController < ApplicationController

  CRM_PROPERTY_SUPPORTED_PROVIDERS = %w[hubspot].freeze
  LIVE_CRM_VALIDATION_UNAVAILABLE_ERROR = "Live CRM verification is temporarily unavailable. Please try again.".freeze

  before_action :authorize_subscription
  before_action :authorize_crm_access!, only: [ :test_crm_mapping, :validate_crm_mapping ]

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
    current_params = form_params.to_h.deep_stringify_keys
    custom_mappings = normalize_custom_crm_mappings!(current_params)
    authorize_crm_access! if crm_mapping_requested?(current_params)

    validation_result = crm_mapping_validation_result(current_params)
    if validation_result&.valid? == false
      error_messages = crm_mapping_validation_errors(validation_result)
      if request.format.json?
        render json: { errors: error_messages }, status: :unprocessable_entity
      else
        render inertia: "forms/new", props: form_editor_props(
          errors: error_messages
        ), status: :unprocessable_entity
      end
      return
    end

    FormService.create_form(current_user, current_params)
    CrmPropertyCreationJob.perform_later(current_user.id, custom_mappings) if custom_mappings.any?

    redirect_to forms_path, status: :see_other
  rescue Crm::MappingValidator::PropertyFetchError => e
    Rails.logger.warn("[FormsController#create] #{e.message}")

    error_messages = [ LIVE_CRM_VALIDATION_UNAVAILABLE_ERROR ]
    if request.format.json?
      render json: { errors: error_messages }, status: :service_unavailable
    else
      render inertia: "forms/new", props: form_editor_props(
        errors: error_messages
      ), status: :unprocessable_entity
    end
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
    form_fields = submitted_crm_mapping_fields(form)

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

  def validate_crm_mapping
    form = current_user.forms.find(params[:id])
    validation_result = Crm::MappingValidator.new(
      user: current_user,
      fields: submitted_crm_mapping_fields(form)
    ).call

    render json: validation_result.as_json, status: validation_result.valid? ? :ok : :unprocessable_entity
  rescue Crm::MappingValidator::PropertyFetchError => e
    Rails.logger.warn("[FormsController#validate_crm_mapping] #{e.message}")

    render json: {
      error: LIVE_CRM_VALIDATION_UNAVAILABLE_ERROR
    }, status: :service_unavailable
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
    current_params = form_params.to_h.deep_stringify_keys
    custom_mappings = normalize_custom_crm_mappings!(current_params)
    authorize_crm_access! if crm_mapping_requested?(current_params)

    validation_result = crm_mapping_validation_result(current_params)
    if validation_result&.valid? == false
      error_messages = crm_mapping_validation_errors(validation_result)
      if request.format.json?
        render json: { errors: error_messages }, status: :unprocessable_entity
      else
        render inertia: "forms/edit", props: form_editor_props(
          form: FormDetailSerializer.new(form).as_json,
          errors: error_messages
        ), status: :unprocessable_entity
      end
      return
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
  rescue Crm::MappingValidator::PropertyFetchError => e
    Rails.logger.warn("[FormsController#update] #{e.message}")

    error_messages = [ LIVE_CRM_VALIDATION_UNAVAILABLE_ERROR ]
    if request.format.json?
      render json: { errors: error_messages }, status: :service_unavailable
    else
      render inertia: "forms/edit", props: form_editor_props(
        form: form ? FormDetailSerializer.new(form).as_json : nil,
        errors: error_messages
      ), status: :unprocessable_entity
    end
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
          contact: service.list_properties(object_type: "contact"),
          company: service.list_properties(object_type: "company")
        }
      rescue StandardError => e
        Rails.logger.error("[FormsController#crm_properties] #{e.message}")
        properties[:hubspot] = { contact: [], company: [] }
      end
    end

    properties
  end

  def active_crm_providers
    return [] unless Crm::Entitlement.new(current_user).allowed?

    current_user.crm_connections.active.distinct.pluck(:provider).select do |provider|
      CRM_PROPERTY_SUPPORTED_PROVIDERS.include?(provider)
    end
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
        fields: permitted_field_attributes
      }
    )
  end

  def normalize_custom_crm_mappings!(form_attributes)
    fields = form_attributes.dig("structure", "fields") || []

    fields.each_with_index.with_object([]) do |(field, index), custom_mappings|
      metadata = field["metadata"] ||= {}
      crm_mapping = metadata["crm_mapping"]
      next unless crm_mapping.is_a?(Hash)

      crm_mapping.each do |provider, mapping|
        next unless mapping.is_a?(Hash)
        next unless mapping["type"] == "custom"

        object_type = mapping["object_type"].to_s.presence || "contact"
        raw_property_name = mapping["property_name"].to_s.presence
        raw_property_name = Crm::KeyParser.property_name(raw_property_name) if raw_property_name.present? && Crm::KeyParser.compound?(raw_property_name)

        fallback_label = field["label"].to_s.presence || "field_#{index + 1}"
        property_name = raw_property_name.presence || fallback_label.parameterize(separator: "_")

        mapping["object_type"] = object_type
        mapping["property_name"] = Crm::KeyParser.build(object_type, property_name)

        custom_mappings << {
          provider: provider.to_s,
          label: fallback_label,
          property_name: property_name,
          object_type: object_type,
          field_type: field["field_type"].to_s,
          options: Array(metadata["options"]),
          allow_multiple: ActiveModel::Type::Boolean.new.cast(metadata["allow_multiple"])
        }
      end
    end.uniq { |mapping| [ mapping[:provider], mapping[:object_type], mapping[:property_name] ] }
  end

  def crm_mapping_validation_result(form_attributes)
    return nil unless Crm::Entitlement.new(current_user).allowed?

    fields = form_attributes.dig("structure", "fields") || []
    return nil if fields.blank?

    Crm::MappingValidator.new(user: current_user, fields: fields).call
  end

  def crm_mapping_validation_errors(validation_result)
    (validation_result.messages + validation_result.issues.map(&:message)).uniq
  end

  def submitted_crm_mapping_fields(form)
    raw_fields = if params.key?(:fields)
      submitted_crm_mapping_fields_params
    else
      form.structure&.dig("fields") || []
    end

    Array(raw_fields).map do |field|
      if field.respond_to?(:to_h)
        field.to_h
      else
        field
      end
    end
  end

  def submitted_crm_mapping_fields_params
    params.permit(fields: permitted_field_attributes).fetch(:fields, [])
  end

  def permitted_field_attributes
    [ :id, :label, :field_type, :required, :position, :allow_multiple, { options: [] }, { metadata: {} } ]
  end

  def crm_mapping_requested?(form_attributes)
    Array(form_attributes.dig("structure", "fields")).any? do |field|
      field.dig("metadata", "crm_mapping").is_a?(Hash) && field.dig("metadata", "crm_mapping").any?
    end
  end

end
