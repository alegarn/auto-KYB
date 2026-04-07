# frozen_string_literal: true

# SettingsPolicy allows any authenticated user — even those with a canceled or
# past-due subscription — to access their account settings.
class SettingsPolicy < ApplicationPolicy

  def show?
    user.present?
  end

  def update?
    user.present?
  end

  def edit?
    user.present?
  end

  def destroy?
    user.present?
  end

end
