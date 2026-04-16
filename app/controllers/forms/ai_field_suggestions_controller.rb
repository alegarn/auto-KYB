# frozen_string_literal: true

module Forms
  class AiFieldSuggestionsController < ApplicationController

    SUPPORTED_AI_PROVIDERS = %w[hubspot].freeze

    before_action :authorize_crm_access!

    def create
      permitted_params = ai_params
      return render_ai_unavailable(permitted_params[:unmapped_fields]) unless SUPPORTED_AI_PROVIDERS.include?(permitted_params[:provider].to_s)

      form = current_user.forms.find(params[:form_id])
      connection = current_user.crm_connections.active.find_by!(provider: permitted_params[:provider])

      result = Crm::AiFieldMapper.new(
        form: form,
        connection: connection,
        unmapped_fields: permitted_params[:unmapped_fields],
        already_mapped: permitted_params[:already_mapped],
        draft_fields: permitted_params[:draft_fields],
        provider: permitted_params[:provider]
      ).call

      render json: {
        suggestions: result.suggestions,
        unmapped_count: result.unmapped_count,
        error: result.error
      }, status: :ok
    rescue ActionController::ParameterMissing
      render json: { error: "provider_required" }, status: :unprocessable_entity
    end

    private

    def ai_params
      permitted = params.permit(
        :provider,
        unmapped_fields: [ :id, :label, :field_type, :required, :position, { metadata: [ :export_key, :allow_multiple, { options: [] } ] } ],
        draft_fields: [ :id, :label, :field_type, :required, :position, { metadata: [ :export_key, :allow_multiple, { options: [] } ] } ],
        already_mapped: []
      )
      permitted.require(:provider)
      permitted
    end

    def render_ai_unavailable(unmapped_fields)
      render json: {
        suggestions: {},
        unmapped_count: Array(unmapped_fields).size,
        error: "ai_unavailable"
      }, status: :ok
    end

  end
end
