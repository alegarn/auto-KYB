class SettingsController < ApplicationController

  def index
    authorize :settings, :show?

    entitlement = Crm::Entitlement.new(current_user)

    render inertia: "Settings/Index", props: {
      user: SettingsUserSerializer.new(current_user, crm_entitlement: entitlement).as_json,
      crm_connections: settings_crm_connections(entitlement)
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

end
