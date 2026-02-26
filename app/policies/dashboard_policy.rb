# frozen_string_literal: true

class DashboardPolicy < ApplicationPolicy
  def show?
    subscribed?
  end
end
