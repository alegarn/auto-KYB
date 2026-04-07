# frozen_string_literal: true

# SubscriptionPolicy allows any authenticated user to manage their subscription,
# including resubscribing after cancellation.
class SubscriptionPolicy < ApplicationPolicy

  def show?
    user.present?
  end

  def create?
    user.present?
  end

  def billing_portal?
    user.present?
  end

  def active?
    user.present? && user.subscribed?
  end

  def required?
    user.present?
  end

end
