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
    gemini_payload = gemini_api_error_payload(e)
    render_error(
      gemini_payload[:message],
      details: gemini_payload[:details],
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

  def gemini_api_error_payload(error)
    error_message = error.message.to_s
    retry_count = error.respond_to?(:retry_count) ? error.retry_count.to_i : 0

    if error_message.include?("Gemini API key not configured")
      return {
        message: "PDF import is unavailable because the Gemini API key is not configured.",
        details: [ "Ask an admin to configure the Gemini API key, then try again." ]
      }
    end

    if error_message.include?("Gemini API timed out")
      return {
        message: retry_count.positive? ? "PDF import timed out after #{retry_count} automatic Gemini #{retry_count == 1 ? 'retry' : 'retries'}." : "PDF import timed out while waiting for Gemini.",
        details: [ "Gemini did not respond in time. Please try again later." ]
      }
    end

    code = gemini_error_code(error_message)
    summary = retry_count.positive? ? "after #{retry_count} automatic Gemini #{retry_count == 1 ? 'retry' : 'retries'}" : "while contacting Gemini"

    case code
    when 429
      {
        message: "PDF import failed #{summary}.",
        details: [
          "Gemini returned a 429 rate-limit or quota error on the final attempt.",
          "Please check Gemini billing and quota, then try again later."
        ]
      }
    when 502, 503, 504
      {
        message: "PDF import failed #{summary}.",
        details: [
          "Gemini returned a #{code} availability error on the final attempt.",
          "The provider was unavailable or under heavy load."
        ]
      }
    when nil
      {
        message: retry_count.positive? ? "PDF import failed #{summary}." : "PDF import failed while contacting Gemini.",
        details: [ "Gemini returned an unexpected error on the final attempt." ]
      }
    else
      {
        message: "PDF import failed #{summary}.",
        details: [ "Gemini returned HTTP #{code} on the final attempt." ]
      }
    end
  end

  def gemini_error_code(error_message)
    match = error_message.match(/Gemini API error \((\d{3})\)/)
    match && match[1].to_i
  end

end
