class Identity::OauthConnectionsController < ApplicationController

  before_action :authorize_settings

  def destroy
    if current_user.provider.blank?
      return redirect_to settings_path,
                         alert: "No Google account is connected.",
                         status: :see_other
    end

    current_user.update!(provider: nil, uid: nil)

    redirect_to settings_path,
                notice: "Google account disconnected.",
                status: :see_other
  end

  private

  def authorize_settings
    authorize :settings, :update?
  end

end
