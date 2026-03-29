# frozen_string_literal: true

class CrmFeaturePolicy < ApplicationPolicy
  def access?
    subscribed? && user.can_use_crm?
  end
end
