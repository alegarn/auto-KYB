class DashboardController < ApplicationController
  def index
    render inertia: "Dashboard/Dashboard", props: {
      user: current_user,
      session_id: current_session_id,
      recent_forms: FormSerializer.collection(current_user.forms.order(created_at: :desc).limit(5))
    }
  end

  private
  # `current_user` and `current_session_id` provided by ApplicationController
end
