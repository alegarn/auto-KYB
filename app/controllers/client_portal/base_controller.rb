class ClientPortal::BaseController < ApplicationController

  # Client portal actions are public to external clients; skip user auth
  skip_before_action :authenticate
  before_action :load_client_form

  private

  def load_client_form
    Current.client_form = ClientPortal::SessionService.current_client_form(cookies)
  end

  def authenticate_client_form!
    unless Current.client_form && !Current.client_form.locked?
      ClientPortal::SessionService.clear_cookie(cookies)
      redirect_to root_path, notice: "Your portal was revoked, you can ask the new form to the form provider", status: :see_other
    end
  end

end
