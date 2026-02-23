class AuthLoadingController < ApplicationController

  def show
    render inertia: "Auth/Loading", props: {
      redirect_to: dashboard_path,
      bootstrap_ready: bootstrap_ready?
    }
  end

  private
    def bootstrap_ready?
      true
    end

end
