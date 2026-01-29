class DashboardController < ApplicationController
  before_action :authenticate
  
  def index
    render inertia: "Dashboard/Dashboard", props: {
      user: current_user,
      session_id: current_session_id
    }
  end

  private

  def current_user
    Current.session&.user
  end

  def iser_signed_in?
    Current.session.present?
  end

  def current_session_id
    Current.session&.id
  end

end
