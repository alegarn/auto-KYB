class SettingsController < ApplicationController

  def index
    render inertia: "Settings/Index", props: {
      user: current_user
    }
  end

  private
  # `current_user` and `current_session_id` provided by ApplicationController

end
