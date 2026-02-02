class DashboardController < ApplicationController
  def index
    render inertia: "Dashboard/Dashboard", props: {
      user: current_user,
      session_id: current_session_id
    }
  end

  private
  # `current_user` and `current_session_id` provided by ApplicationController
end
