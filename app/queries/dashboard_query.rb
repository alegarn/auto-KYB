class DashboardQuery

  include Rails.application.routes.url_helpers

  FORM_STEP_KEY = "form".freeze
  CLIENT_STEP_KEY = "client".freeze
  INVITE_STEP_KEY = "invite".freeze
  CRM_STEP_KEY = "crm".freeze

  def initialize(user)
    @user = user
  end

  def stats
    {
      total_clients: total_clients_count,
      validated_clients: client_scope.where(form_status: "validated").count,
      active_clients: client_scope.where(form_status: "active").count,
      linked_clients: client_scope.where(form_status: "linked").count
    }
  end

  def recent_forms(limit: 5)
    form_scope.order(updated_at: :desc).limit(limit)
  end

  def clients_scope
    client_scope
  end

  def total_clients_count
    @total_clients_count ||= client_scope.count
  end

  def onboarding_summary
    quick_steps = onboarding_steps

    {
      visible: onboarding_visible?(quick_steps),
      variant: onboarding_variant,
      progress_percent: onboarding_progress_percent(quick_steps),
      completion_rule: onboarding_completion_rule,
      quick_steps: quick_steps,
      can_dismiss: true,
      detailed_view_seen: @user.dashboard_onboarding_detailed_view_seen?
    }
  end

  private

  def onboarding_variant
    crm_entitlement.allowed? ? "pro" : "basic"
  end

  def onboarding_completion_rule
    onboarding_variant == "pro" ? "pro_with_crm" : "basic_core"
  end

  def onboarding_steps
    steps = [
      onboarding_step(FORM_STEP_KEY, has_workspace_form?, form_step_href),
      onboarding_step(CLIENT_STEP_KEY, has_clients?, client_step_href),
      onboarding_step(INVITE_STEP_KEY, has_invited_client?, invite_step_href)
    ]

    steps << onboarding_step(CRM_STEP_KEY, crm_connected?, settings_path) if onboarding_variant == "pro"
    steps
  end

  def onboarding_step(key, complete, href)
    {
      key: key,
      complete: complete,
      href: href
    }
  end

  def onboarding_visible?(quick_steps)
    return false if @user.dashboard_onboarding_dismissed?

    quick_steps.any? { |step| !step[:complete] }
  end

  def onboarding_progress_percent(quick_steps)
    return 100 if quick_steps.empty?

    ((quick_steps.count { |step| step[:complete] }.to_f / quick_steps.size) * 100).round
  end

  def has_workspace_form?
    @has_workspace_form ||= form_scope.exists?
  end

  def has_clients?
    @has_clients ||= client_scope.exists?
  end

  def has_invited_client?
    @has_invited_client ||= ClientForm.joins(:client).where(clients: { user_id: @user.id }).exists?
  end

  def crm_connected?
    @crm_connected ||= @user.crm_connections.active.exists?
  end

  def crm_entitlement
    @crm_entitlement ||= Crm::Entitlement.new(@user)
  end

  def latest_form_id
    @latest_form_id ||= form_scope.order(updated_at: :desc).pick(:id)
  end

  def latest_client_id
    @latest_client_id ||= client_scope.order(updated_at: :desc).pick(:id)
  end

  def form_step_href
    return new_form_path if latest_form_id.blank?

    edit_form_path(latest_form_id)
  end

  def client_step_href
    return new_client_path if latest_client_id.blank?

    client_path(latest_client_id)
  end

  def invite_step_href
    return new_client_path if latest_client_id.blank?

    client_path(latest_client_id)
  end

  def client_scope
    @client_scope ||= (
      @user.respond_to?(:clients) ? @user.clients : Client.none
    )
  end

  def form_scope
    @form_scope ||= (
      @user.respond_to?(:forms) ? @user.forms : Form.none
    )
  end

end
