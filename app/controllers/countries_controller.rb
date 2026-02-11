class CountriesController < ApplicationController
  before_action :require_authentication_for_api

  # Returns the countries defined in config/countries.yml as JSON
  def index
    expires_in 24.hours, public: true
    if stale?(etag: COUNTRIES)
      render json: COUNTRIES
    end
  end

  private

  def require_authentication_for_api
    return if Current.session&.user.present?

    if request.format.json?
      head :unauthorized
    else
      redirect_to(sign_in_path)
    end
  end
end
