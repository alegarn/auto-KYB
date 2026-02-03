module TestAuthHelpers
  def sign_in_user(user = nil)
    user ||= FactoryBot.create(:user)
    # Controllers rely on Current.session; create a session and set it
    session_record = user.sessions.create!
    # Set a cookie so requests authenticate using the session record
    if defined?(page) && page.respond_to?(:driver)
      # Rack::Test driver
      if page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:set_cookie)
        page.driver.browser.set_cookie("session_token=#{session_record.id}")
      end
    end

    # For request specs we can set the test cookie jar if available
    if respond_to?(:cookies)
      if cookies.respond_to?(:signed)
        cookies.signed[:session_token] = session_record.id
      else
        cookies[:session_token] = session_record.id
      end
    elsif defined?(request) && request.respond_to?(:cookies)
      request.cookies['session_token'] = session_record.id
    end

    # Ensure Current is set for the current test process and initialize defaults
    Current.session = session_record
    FormService.initialize_default_for_user(user)
    user
  end

  def current_user
    TestAuthHelpers::CURRENT_USER
  end
end

RSpec.configure do |config|
  config.include TestAuthHelpers
end
