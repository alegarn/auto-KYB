# frozen_string_literal: true

module Forms
  class AiFieldSuggestionsController < ApplicationController

    before_action :authorize_crm_access!

    def create
      permitted_params = ai_params
      form = current_user.forms.find(params[:form_id])
      connection = current_user.crm_connections.active.find_by!(provider: permitted_params[:provider])

      result = Crm::AiFieldMapper.new(
        form: form,
        connection: connection,
        unmapped_fields: permitted_params[:unmapped_fields],
        already_mapped: permitted_params[:already_mapped],
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
        unmapped_fields: [ :id, :label, :field_type ],
        already_mapped: []
      )
      permitted.require(:provider)
      permitted
    end

  end
end
