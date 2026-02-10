module TestAuthHelpers
  def sign_in_user(user = nil)
    user ||= FactoryBot.create(:user)
    # For system tests using a JS browser driver, perform an actual sign-in via the UI
    if defined?(page) && page.respond_to?(:driver) && page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:manage)
      visit sign_in_path
      fill_in 'Username', with: user.email
      fill_in 'Password', with: 'a_secure_password_123'
      click_button 'Sign In'
    else
      # Controllers rely on Current.session; create a session and set it
      session_record = user.sessions.create!
      # Set a cookie so requests authenticate using the session record
      if defined?(page) && page.respond_to?(:driver)
        if page.driver.respond_to?(:browser)
          browser = page.driver.browser
          if browser.respond_to?(:set_cookie)
            # Rack::Test driver
            browser.set_cookie("session_token=#{session_record.id}")
          elsif browser.respond_to?(:manage)
            # Selenium/JS drivers should have been handled above, but keep a fallback
            begin
              page.visit('/') if page.current_url == 'about:blank'
            rescue StandardError
              page.visit('/') rescue nil
            end
            begin
              uri = URI.parse(page.current_url) rescue nil
              cookie_opts = { name: 'session_token', value: session_record.id.to_s, path: '/' }
              cookie_opts[:domain] = uri.host if uri && uri.host
              browser.manage.add_cookie(cookie_opts)
            rescue Selenium::WebDriver::Error::InvalidCookieDomainError, Selenium::WebDriver::Error::InvalidArgumentError
              begin
                browser.manage.add_cookie(name: 'session_token', value: session_record.id.to_s, path: '/')
              rescue StandardError
                begin
                  page.execute_script("document.cookie = 'session_token=#{session_record.id}; path=/';")
                rescue StandardError
                end
              end
            end
          end
        end
      end
    end

    # Ensure we have a session_record (UI sign-in may have created one)
    session_record ||= user.sessions.last

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
