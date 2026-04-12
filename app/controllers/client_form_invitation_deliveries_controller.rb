class ClientFormInvitationDeliveriesController < ApplicationController

  before_action :authorize_subscription
  before_action :set_client_form
  before_action :ensure_decision_pending

  # GET /client_forms/:client_form_id/invitation_delivery
  def show
    client = @client_form.client

    # Determine whether auto-send prerequisites are met (no side-effects on GET)
    setting = current_user.client_invitation_email_setting
    auto_send = setting&.auto_send? && client.email.present?

    render inertia: "Clients/InvitationDeliveryDecision", props: {
      client_form_id: @client_form.id,
      client: {
        id: client.id,
        name: client.name,
        email: client.email
      },
      form: { name: @client_form.form.name },
      has_email: client.email.present?,
      auto_send: auto_send,
      flash_message: flash[:alert]
    }
  end

  # POST /client_forms/:client_form_id/invitation_delivery
  def create
    session_store = invitation_session_store
    password = session_store.live_password(@client_form.id)

    unless password
      session_store.complete_decision(@client_form.id)
      redirect_to password_reveal_client_form_path(@client_form),
        alert: "Password is no longer available or expired."
      return
    end

    if params[:send_now] == "true"
      handle_send_now(session_store, password)
    else
      handle_not_now(session_store)
    end
  end

  private

  def handle_send_now(session_store, password)
    client = @client_form.client

    if client.email.blank?
      flash[:alert] = "This client does not have an email address."
      redirect_to client_form_invitation_delivery_path(@client_form)
      return
    end

    result = ClientPortalInvitationDeliveryService.call(
      client_form: @client_form,
      password: password,
      user: current_user
    )

    if result.success?
      session_store.complete_decision(@client_form.id)
      redirect_to password_reveal_client_form_path(@client_form),
        notice: "Invitation email sent to #{client.email}.",
        status: :see_other
    else
      flash[:alert] = result.error
      redirect_to client_form_invitation_delivery_path(@client_form)
    end
  end

  def handle_not_now(session_store)
    session_store.complete_decision(@client_form.id)
    redirect_to password_reveal_client_form_path(@client_form), status: :see_other
  end

  def authorize_subscription
    authorize :client_form, :index?
  end

  def set_client_form
    @client_form = ClientForm.includes(:client, :form).find(params[:client_form_id])

    unless current_user && @client_form.client.user_id == current_user.id
      redirect_to(clients_path, alert: "You don't have permission to access this form") and return
    end
  end

  def ensure_decision_pending
    session_store = invitation_session_store

    unless session_store.decision_pending?(@client_form.id)
      redirect_to password_reveal_client_form_path(@client_form)
    end
  end

end
