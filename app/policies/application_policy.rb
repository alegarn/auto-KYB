# frozen_string_literal: true

# ApplicationPolicy is the base for all Pundit policies.
#
# Default rules require the user to be present AND have an active or trialing subscription.
# Override in sub-policies to allow access to unauthenticated or non-subscribed users
# (e.g. SettingsPolicy, SubscriptionPolicy).
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    subscribed?
  end

  def show?
    subscribed?
  end

  def create?
    subscribed?
  end

  def new?
    create?
  end

  def update?
    subscribed?
  end

  def edit?
    update?
  end

  def destroy?
    subscribed?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  # True when a user is logged in with an active or trialing subscription.
  def subscribed?
    user.present? && (user.active_subscription? || user.trialing?)
  end
end
