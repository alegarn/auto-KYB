module ClientPortal
  class UploadedFilesController < ClientPortal::BaseController

    skip_before_action :verify_authenticity_token
    before_action :authenticate_client_form!

    def create
      client_form = Current.client_form
      client = client_form.client
      form_response = client_form.form_responses.order(:version).last

      file = params[:file]
      field_key = params[:field_key]

      unless file
        return render json: { error: "No file provided" }, status: :unprocessable_entity
      end

      unless field_key.present?
        return render json: { error: "Field key is required" }, status: :unprocessable_entity
      end

      result = FileUploadService.call(
        client: client,
        field_key: field_key,
        file: file,
        form_response: form_response
      )

      if result.success?
        uf = result.uploaded_file
        render json: {
          id: uf.id,
          field_key: uf.field_key,
          filename: uf.filename,
          content_type: uf.content_type,
          byte_size: uf.byte_size,
          uploaded_at: uf.uploaded_at.iso8601,
          status: uf.status
        }, status: :created
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

  end
end
