class FormsController < ApplicationController
  def index
    render inertia: "Forms/Index", props: {
      user: current_user,
      session_id: current_session_id
    }
  end

  private

  def current_user
    Current.session&.user
  end

  def current_session_id
    Current.session&.id
  end
end
