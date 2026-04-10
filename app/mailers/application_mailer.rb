class ApplicationMailer < ActionMailer::Base

  default from: ENV.fetch("MAILER_FROM", "hello@quick-kyb.com")
  layout "mailer"
  # Retry on network timeouts
  rescue_from Net::OpenTimeout, Net::ReadTimeout do |exception|
    Rails.logger.error "Mailer Timeout: #{exception.message}"
    raise exception
  end

end
