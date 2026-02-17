module ClientPortal
  class UploadedFilesController < ClientPortal::BaseController

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
        if inertia_request?
          redirect_to client_portal_form_response_path,
            notice: "File uploaded",
            status: :see_other
        else
          render json: {
            id: uf.id,
            field_key: uf.field_key,
            filename: uf.filename,
            content_type: uf.content_type,
            byte_size: uf.byte_size,
            uploaded_at: uf.uploaded_at.iso8601,
            status: uf.status
          }, status: :created
        end
      else
        if inertia_request?
          redirect_to client_portal_form_response_path,
            alert: result.error,
            status: :see_other
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end
    end

    private

    def inertia_request?
      request.headers["X-Inertia"].present?
    end

  end
end
