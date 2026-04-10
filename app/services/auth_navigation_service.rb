# frozen_string_literal: true

class AuthNavigationService

  def initialize(user:, routes:)
    @user = user
    @routes = routes
  end

  def post_login_path
    return routes.auth_setup_settings_path unless user.onboarding_completed?

    routes.auth_loading_path
  end

  def public_auth_cta
    return nil unless user

    if user.subscribed?
      return {
        label: user.onboarding_completed? ? "Dashboard" : "Finish Setup",
        href: user.onboarding_completed? ? routes.dashboard_path : routes.auth_setup_settings_path
      }
    end

    {
      label: "Resume Subscription",
      href: routes.sign_up_path
    }
  end

  def registration_redirect_path
    return nil unless user&.subscribed?

    public_auth_cta.fetch(:href)
  end

  private
  attr_reader :user, :routes
end