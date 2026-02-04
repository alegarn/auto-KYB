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

Rack::Attack.throttle("client_forms/password_reveal/ip_access", limit: 5, period: 5.minutes) do |req|
  next unless req.get?
  match = req.path.match(%r{\A/client_forms/([^/]+)/password_reveal\z})
  next unless match

  client_form_id = match[1]
  access_token = begin
    ClientForm.find_by(id: client_form_id)&.access_token
  rescue StandardError
    nil
  end

  "#{req.ip}:#{access_token || client_form_id}"
end

Rack::Attack.throttled_responder = lambda do |_request|
  [
    429,
    { "Content-Type" => "application/json" },
    [ { error: "Too many requests. Please try again later." }.to_json ]
  ]
end
