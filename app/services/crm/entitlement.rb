# frozen_string_literal: true

module Crm
  class Entitlement
    def initialize(user)
      @user = user
    end

    def allowed?
      reason == :allowed
    end

    def reason
      return :unauthenticated if user.blank?
      return :subscription_inactive unless subscription_active?
      return :plan_insufficient unless plan_eligible?

      :allowed
    end

    def plan_eligible?
      user.present? && user.crm_plan_eligible?
    end

    def subscription_active?
      user.present? && (user.active_subscription? || user.trialing?)
    end

    def auto_sync_allowed?
      allowed? && user.crm_auto_sync_on_portal_submit
    end

    def as_json(*)
      {
        allowed: allowed?,
        reason: reason.to_s,
        plan_eligible: plan_eligible?,
        subscription_active: subscription_active?,
        auto_sync_allowed: auto_sync_allowed?
      }
    end

    private

    attr_reader :user
  end
end