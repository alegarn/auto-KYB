module ClientPortal
  class ConfirmationsController < ClientPortal::BaseController

    # Minimal confirmation page shown after successful validation
    def show
      client_form = Current.client_form

      render inertia: "ClientPortal/Confirmation", props: {
        client: client_form ? { id: client_form.client.id, name: client_form.client.name } : nil,
        form: client_form ? FormDetailSerializer.new(client_form.form).as_json : nil
      }
    end

  end
end
