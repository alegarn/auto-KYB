Rails.application.config.gemini = ActiveSupport::OrderedOptions.new
Rails.application.config.gemini.api_key = Rails.application.credentials.dig(:gemini, :api_key) || ENV["GEMINI_API_KEY"]