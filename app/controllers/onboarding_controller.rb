class OnboardingController < ApplicationController

  before_action :authorize_dashboard

  def dismiss
    current_user.dismiss_dashboard_onboarding!
    redirect_back fallback_location: dashboard_path, status: :see_other
  end

  def details_seen
    current_user.mark_dashboard_onboarding_details_seen!
    redirect_back fallback_location: dashboard_path, status: :see_other
  end

  def guide_seen
    guide_key = params[:guide_key].to_s
    current_user.mark_dashboard_onboarding_guide_seen!(guide_key)
    redirect_back fallback_location: dashboard_path, status: :see_other
  end

  def reset
    reset_progress = params[:reset_progress] == true || params[:reset_progress] == "true"
    current_user.reset_dashboard_onboarding!(reset_progress: reset_progress)

    redirect_back fallback_location: dashboard_path, status: :see_other
  end

  private

  def authorize_dashboard
    authorize :dashboard, :show?
  end

end