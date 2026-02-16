class ClientPortal::SessionsController < ClientPortal::BaseController

  def new
    @access_token = params[:access_token]
    client_form = ClientForm.find_by(access_token: @access_token)
    portal_status = client_form.nil? || client_form.locked? ? "gone" : "active"

    render inertia: "ClientPortal/Login", props: {
      access_token: @access_token,
      portal_status: portal_status,
      flash_message: flash_message_payload
    }
  end

  def create
    client_form = ClientForm.find_by(access_token: params[:access_token])

    if client_form.nil? || client_form.locked?
      redirect_to client_portal_login_path(params[:access_token]),
        alert: "This portal is no longer available."
      return
    end

    if client_form&.authenticate(params[:password])
      ClientPortal::SessionService.set_cookie(cookies, client_form)
      redirect_to client_portal_form_response_path
    else
      redirect_to client_portal_login_path(params[:access_token]),
        alert: "Invalid password. Please try again."
    end
  end

  def destroy
    ClientPortal::SessionService.clear_cookie(cookies)
    redirect_to root_path
  end

  private

  def flash_message_payload
    if flash[:alert].present?
      { type: "alert", message: flash[:alert] }
    elsif flash[:notice].present?
      { type: "notice", message: flash[:notice] }
    end
  end

end
