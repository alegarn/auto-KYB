class FormImportsController < ApplicationController

  MAX_FILE_SIZE = 10.megabytes
  PDF_SIGNATURE_BYTES = 5
  PDF_SIGNATURE_PREFIX = "%PDF-".freeze

  before_action :authorize_subscription

  def create
    pdf_file = params.require(:pdf_file)

    unless uploaded_pdf_file?(pdf_file)
      render json: { success: false, error: "Only PDF files are accepted" }, status: :unprocessable_entity
      return
    end

    if pdf_file.size > MAX_FILE_SIZE
      render json: { success: false, error: "File too large (max 10 MB)" }, status: :unprocessable_entity
      return
    end

    unless pdf_signature?(pdf_file)
      render json: { success: false, error: "Only PDF files are accepted" }, status: :unprocessable_entity
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
      render json: {
        success: false,
        error: "The generated form structure is invalid",
        details: result.errors
      }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing
    render json: { success: false, error: "No PDF file provided" }, status: :unprocessable_entity
  rescue GeminiClient::ApiError
    render json: { success: false, error: "AI processing failed. Please try again." }, status: :unprocessable_entity
  rescue FormJsonExtractor::ExtractionError
    render json: { success: false, error: "Could not interpret the AI response. Please try again." }, status: :unprocessable_entity
  end

  def confirm
    form_data = params.require(:form_data)

    unless form_data.is_a?(ActionController::Parameters)
      render json: { success: false, error: "Invalid form data" }, status: :unprocessable_entity
      return
    end

    form_data = form_data.permit!.to_h
    result = PdfFormImportService.normalize_form_data(form_data)

    unless result.success
      render json: { success: false, error: "Invalid form data", details: result.errors }, status: :unprocessable_entity
      return
    end

    form = FormService.create_form(current_user, result.data.with_indifferent_access)
    render json: { success: true, form_id: form.id }, status: :created
  rescue ActionController::ParameterMissing
    render json: { success: false, error: "No form data provided" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  rescue FormService::DuplicateExportKeysError => e
    render json: {
      success: false,
      error: "Export mapping keys must be unique",
      details: [ "Duplicate keys: #{e.duplicate_keys.join(', ')}" ]
    }, status: :unprocessable_entity
  end

  private

  def authorize_subscription
    authorize :form, :index?
  end

  def pdf_signature?(pdf_file)
    signature = pdf_file.read(PDF_SIGNATURE_BYTES)
    pdf_file.rewind
    signature&.start_with?(PDF_SIGNATURE_PREFIX)
  end

  def uploaded_pdf_file?(pdf_file)
    pdf_file.respond_to?(:size) && pdf_file.respond_to?(:read) && pdf_file.respond_to?(:rewind)
  end

end
