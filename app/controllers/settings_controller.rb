class SettingsController < ApplicationController

  def index
    authorize :settings, :show?

    entitlement = Crm::Entitlement.new(current_user)

    render inertia: "Settings/Index", props: {
      user: SettingsUserSerializer.new(current_user, crm_entitlement: entitlement).as_json,
      crm_connections: settings_crm_connections(entitlement),
      client_invitation_email_setting: serialize_invitation_email_setting
    }
  end

  # GET /settings/auth_setup — first-time login: choose auth method
  def auth_setup
    authorize :settings, :show?
    render inertia: "Settings/AuthSetup", props: {
      user: { email: current_user.email },
      google_auth_url: "/auth/google_oauth2"
    }
  end

  # PATCH /settings/auth_setup — mark onboarding as completed (email choice)
  def complete_onboarding
    authorize :settings, :update?
    current_user.update!(onboarding_completed: true)
    redirect_to auth_loading_path, notice: "You're all set!", status: :see_other
  end

  def update_crm_preferences
    authorize :settings, :update?
    authorize_crm_access!

    current_user.update!(crm_preference_params)
    redirect_to settings_path, status: :see_other
  end

  def update_invite_auto_send
    authorize :settings, :update?

    setting = current_user.client_invitation_email_setting ||
              current_user.build_client_invitation_email_setting

    setting.skip_placeholder_validation = true
    setting.update!(invite_auto_send_params)
    redirect_to settings_path, status: :see_other
  end

  def update_client_invitation_email
    authorize :settings, :update?

    setting = current_user.client_invitation_email_setting ||
              current_user.build_client_invitation_email_setting

    if setting.update(invitation_email_params)
      redirect_to settings_path, notice: "Invite email settings saved.", status: :see_other
    else
      entitlement = Crm::Entitlement.new(current_user)
      render inertia: "Settings/Index", props: {
        user: SettingsUserSerializer.new(current_user, crm_entitlement: entitlement).as_json,
        crm_connections: settings_crm_connections(entitlement),
        client_invitation_email_setting: serialize_invitation_email_setting(setting),
        errors: setting.errors.messages
      }, status: :unprocessable_entity
    end
  end

  private
  # `current_user` and `current_session_id` provided by ApplicationController

  def crm_preference_params
    params.require(:settings).permit(:crm_auto_sync_on_portal_submit)
  end

  def settings_crm_connections(entitlement)
    return [] unless entitlement.allowed?

    authorize_crm_access!
    current_user.crm_connections.as_json(only: [ :id, :provider, :status, :updated_at ])
  end

  def invite_auto_send_params
    params.require(:client_invitation_email_setting).permit(:auto_send)
  end

  def invitation_email_params
    params.require(:client_invitation_email_setting).permit(:subject_template, :body_template)
  end

  def serialize_invitation_email_setting(setting = nil)
    setting ||= current_user.client_invitation_email_setting
    return { auto_send: false, subject_template: nil, body_template: nil } unless setting

    {
      auto_send: setting.auto_send,
      subject_template: setting.subject_template,
      body_template: setting.body_template
    }
  end

end
