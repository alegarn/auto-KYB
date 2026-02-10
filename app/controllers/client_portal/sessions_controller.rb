class ClientPortal::SessionsController < ClientPortal::BaseController

  skip_before_action :verify_authenticity_token, only: [ :create ]

  def new
    @access_token = params[:access_token]
    client_form = ClientForm.find_by(access_token: @access_token)
    portal_status = client_form.nil? || client_form.locked? ? "gone" : "active"

    render inertia: "ClientPortal/Login", props: {
      access_token: @access_token,
      portal_status: portal_status
    }
  end

  def create
    client_form = ClientForm.find_by(access_token: params[:access_token])

    if client_form.nil? || client_form.locked?
      head :gone
      return
    end

    if client_form&.authenticate(params[:password])
      ClientPortal::SessionService.set_cookie(cookies, client_form)
      redirect_to client_portal_form_response_path
    else
      head :unauthorized
    end
  end

  def destroy
    ClientPortal::SessionService.clear_cookie(cookies)
    redirect_to root_path
  end

end
