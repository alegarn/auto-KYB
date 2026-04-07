class SettingsUserSerializer

  def initialize(user, crm_entitlement: Crm::Entitlement.new(user))
    @user = user
    @crm_entitlement = crm_entitlement
  end

  def as_json(*)
    {
      "id" => @user.id,
      "email" => @user.email,
      "provider" => @user.provider,
      "created_at" => @user.created_at&.iso8601,
      "subscription_status" => @user.subscription_status,
      "subscription_ends_at" => @user.subscription_ends_at&.iso8601,
      "crm_auto_sync_on_portal_submit" => @user.crm_auto_sync_on_portal_submit,
      "plan" => @user.plan,
      "can_use_crm" => @crm_entitlement.allowed?
    }
  end

end
