# spec/support/omniauth.rb
#
# Enables OmniAuth test mode to bypass CSRF protection in request specs.
# OmniAuth middleware intercepts /auth/:provider/callback and populates
# request.env['omniauth.auth'] from OmniAuth.config.mock_auth[provider].
# Use the `mock_omniauth` helper to configure the auth hash before hitting
# the callback route.

OmniAuth.config.test_mode = true
OmniAuth.config.on_failure = proc { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}

module OmniAuthTestHelpers
  # Sets OmniAuth.config.mock_auth for the given provider.
  # Must be called in a before block before requesting /auth/:provider/callback.
  def mock_omniauth(provider, uid:, email:, info: {})
    OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
      'provider' => provider.to_s,
      'uid'      => uid,
      'info'     => { 'email' => email }.merge(info)
    )
  end
end

RSpec.configure do |config|
  config.include OmniAuthTestHelpers, type: :request

  config.after(:each, type: :request) do
    OmniAuth.config.mock_auth = {}
    Rails.application.env_config.delete('omniauth.auth')
  end
end
