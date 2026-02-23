class CountriesController < ApplicationController

  # Returns the countries defined in config/countries.yml as JSON
  def index
    expires_in 24.hours, public: true
    if stale?(etag: COUNTRIES)
      render json: COUNTRIES
    end
  end

end
