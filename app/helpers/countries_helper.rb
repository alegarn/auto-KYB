module CountriesHelper
  # Returns an array suitable for Rails select helpers:
  # [ ["United States", "US"], ["France", "FR"], ... ]
  def country_options_for_select
    COUNTRY_OPTIONS
  end
end
