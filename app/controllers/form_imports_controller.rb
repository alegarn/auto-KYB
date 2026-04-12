class FormImportsController < ApplicationController

  before_action :authorize_forms_access

  def create
    pdf_file = params.require(:pdf_file)
    validation = PdfImportUploadValidator.validate(pdf_file)

    unless validation.valid?
      render_error(validation.error, log_context: upload_context(pdf_file))
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
  rescue GeminiClient::ApiError => e
    render_error(
      "AI processing failed. Please try again.",
      log_details: [ e.message ],
      log_context: upload_context(pdf_file)
    )
  rescue FormJsonExtractor::ExtractionError => e
    render_error(
      "Could not interpret the AI response. Please try again.",
      log_details: [ e.message ],
      log_context: upload_context(pdf_file)
    )
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

  def render_error(message, details: nil, status: :unprocessable_entity, log_details: nil, log_context: nil)
    log_payload = log_details || details
    log_parts = [ "[FormImportsController##{action_name}] #{message}" ]
    log_parts << "details=#{log_payload.inspect}" if log_payload.present?
    log_parts << "context=#{log_context.inspect}" if log_context.present?

    Rails.logger.warn(log_parts.join(" "))

    render json: {
      success: false,
      error: message,
      details: details
    }.compact, status: status
  end

  def upload_context(pdf_file)
    return unless pdf_file.respond_to?(:size)

    {
      original_filename: pdf_file.respond_to?(:original_filename) ? pdf_file.original_filename : nil,
      content_type: pdf_file.respond_to?(:content_type) ? pdf_file.content_type : nil,
      size: pdf_file.size
    }.compact
  end

end
