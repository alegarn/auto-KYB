# frozen_string_literal: true

# Configure Rack::Attack for client portal login throttling
Rack::Attack.cache.store = Rails.cache

# Throttle by access_token + IP for client portal login attempts
Rack::Attack.throttle("client_portal/login/ip_access", limit: 5, period: 20.seconds) do |req|
  next unless req.post?
  next unless req.path.match?(%r{\A/client_portal/login/[^/]+\z})

  access_token = req.path.split("/").last
  "#{req.ip}:#{access_token}"
end

Rack::Attack.throttled_response = lambda do |_env|
  [
    429,
    { "Content-Type" => "application/json" },
    [ { error: "Too many login attempts. Please try again later." }.to_json ]
  ]
end
