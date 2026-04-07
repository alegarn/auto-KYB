# frozen_string_literal: true

class CrmFeaturePolicy < ApplicationPolicy

  def access?
    entitlement.allowed?
  end

  def reason
    entitlement.reason
  end

  private

  def entitlement
    @entitlement ||= Crm::Entitlement.new(user)
  end

end
