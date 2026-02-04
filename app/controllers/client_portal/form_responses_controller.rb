module ClientPortal
  class FormResponsesController < ClientPortal::BaseController
    skip_before_action :verify_authenticity_token, only: [:update]
    before_action :authenticate_client_form!

    def show
      client_form = Current.client_form

      render inertia: 'ClientPortal/FormResponse', props: {
        client: { id: client_form.client.id, name: client_form.client.name },
        form: FormDetailSerializer.new(client_form.form).as_json,
        last_response: last_response_payload(client_form)
      }
    end

    def update
      client_form = Current.client_form

      data = params.dig(:form_response, :data) || {}
      validate = ActiveModel::Type::Boolean.new.cast(params.dig(:form_response, :validate))

      begin
        resp = client_form.save_response!(data: data, validate: validate)
      rescue ActiveRecord::RecordInvalid
        return head :forbidden
      end

      if validate
        ClientPortal::SessionService.clear_cookie(cookies)
        redirect_to root_path, status: :see_other
      else
        render json: { version: resp.version }, status: :ok
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
