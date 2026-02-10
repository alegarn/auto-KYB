module ClientPortal
  class FormResponsesController < ClientPortal::BaseController

    skip_before_action :verify_authenticity_token, only: [ :update ]
    before_action :authenticate_client_form!

    def show
      client_form = Current.client_form

      render inertia: "ClientPortal/FormResponse", props: {
        client: { id: client_form.client.id, name: client_form.client.name },
        form: FormDetailSerializer.new(client_form.form).as_json,
        last_response: last_response_payload(client_form)
      }
    end

    def update
      client_form = Current.client_form

      data = params.dig(:form_response, :data)
      validate = ActiveModel::Type::Boolean.new.cast(params.dig(:form_response, :validate))
      partial = ActiveModel::Type::Boolean.new.cast(params.dig(:form_response, :partial))
      base_version = params.dig(:form_response, :base_version)
      base_version = base_version.to_i if base_version.present?

      saver = ClientPortal::FormResponseSaver.new(
        client_form: client_form,
        data: data,
        validate: validate,
        partial: partial,
        base_version: base_version
      )

      begin
        result = saver.save
      rescue ActiveRecord::RecordInvalid
        return render inertia: "ClientPortal/FormResponse", props: {
          flash_message: {
            type: "alert",
            message: "This form is locked or no longer available."
          }
        }, status: :ok
      end

      if result.conflict
        return render inertia: "ClientPortal/FormResponse", props: {
          flash_message: {
            type: "alert",
            message: result.error
          }
        }, status: :ok
      end

      if validate
        ClientPortal::SessionService.clear_cookie(cookies)
        redirect_to client_portal_confirmation_path, status: :see_other
      else
        render inertia: "ClientPortal/FormResponse", props: {
          last_response: last_response_payload(client_form),
          flash_message: { type: "notice", message: "Form response saved successfully." }
        }, status: :ok
      end
    end

    private

    def last_response_payload(client_form)
      lr = client_form.form_responses.order(:version).last
      return nil unless lr
      { data: lr.data, version: lr.version, created_at: lr.created_at.iso8601 }
    end

  end
end
