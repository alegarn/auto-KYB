class FormImportsController < ApplicationController

  before_action :authorize_forms_access

  def create
    pdf_file = params.require(:pdf_file)
    validation = PdfImportUploadValidator.validate(pdf_file)

    unless validation.valid?
      render_error(validation.error)
      return
    end

    result = PdfFormImportService.call(pdf_file)

    if result.success
      render json: {
        success: true,
        form_data: result.data,
        warnings: result.warnings,
        field_count: result.data.dig("structure", "fields")&.size || 0
      }, status: :ok
    else
      render_error("The generated form structure is invalid", details: result.errors)
    end
  rescue ActionController::ParameterMissing
    render_error("No PDF file provided")
  rescue GeminiClient::ApiError
    render_error("AI processing failed. Please try again.")
  rescue FormJsonExtractor::ExtractionError
    render_error("Could not interpret the AI response. Please try again.")
  end

  def confirm
    form_data = params.require(:form_data)

    unless form_data.is_a?(ActionController::Parameters)
      render_error("Invalid form data")
      return
    end

    form_data = form_data.permit!.to_h
    result = PdfFormImportService.normalize_form_data(form_data)

    unless result.success
      render_error("Invalid form data", details: result.errors)
      return
    end

    form = FormService.create_form(current_user, result.data.with_indifferent_access)
    render json: { success: true, form_id: form.id }, status: :created
  rescue ActionController::ParameterMissing
    render_error("No form data provided")
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.join(", "))
  rescue FormService::DuplicateExportKeysError => e
    render_error("Export mapping keys must be unique", details: [ "Duplicate keys: #{e.duplicate_keys.join(', ')}" ])
  end

  private

  def authorize_forms_access
    authorize :form, :index?
  end

  def render_error(message, details: nil, status: :unprocessable_entity)
    render json: {
      success: false,
      error: message,
      details: details
    }.compact, status: status
  end

end
