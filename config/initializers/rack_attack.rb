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

Rack::Attack.throttle("client_portal/uploads/client", limit: 10, period: 60.seconds) do |req|
  next unless req.post?
  next unless req.path == "/client_portal/uploaded_files"

  cookie_value = req.cookies["client_portal_session"]
  cookie_value.presence
end

form_imports_discriminator = lambda do |req|
  session_token = req.cookies["session_token"].presence || "anonymous"
  "#{req.ip}:#{session_token}"
end

signed_session_token = lambda do |req|
  ActionDispatch::Request.new(req.env).cookie_jar.signed[:session_token].presence
rescue StandardError
  nil
end

ai_field_suggestions_discriminator = lambda do |req|
  session_token = signed_session_token.call(req) || req.cookies["session_token"].presence
  session_user_id = begin
    Session.find_by(id: session_token)&.user_id
  rescue StandardError
    nil
  end

  session_user_id.presence || "#{req.ip}:#{session_token || 'anonymous'}"
end

Rack::Attack.throttle("form_imports/preview", limit: 5, period: 60.seconds) do |req|
  next unless req.post?
  next unless req.path.match?(%r{\A/form_imports(?:\.[^/]+)?\z})

  form_imports_discriminator.call(req)
end

Rack::Attack.throttle("form_imports/confirm", limit: 5, period: 60.seconds) do |req|
  next unless req.post?
  next unless req.path.match?(%r{\A/form_imports/confirm(?:\.[^/]+)?\z})

  form_imports_discriminator.call(req)
end

Rack::Attack.throttle("forms/ai_field_suggestions", limit: 10, period: 1.day) do |req|
  next unless req.post?
  next unless req.path.match?(%r{\A/forms/[^/]+/ai_field_suggestions(?:\.[^/]+)?\z})

  ai_field_suggestions_discriminator.call(req)
end

Rack::Attack.throttled_responder = lambda do |request|
  error_payload = if request.env["rack.attack.matched"] == "forms/ai_field_suggestions"
    { error: "rate_limited" }
  else
    { error: "Too many requests. Please try again later." }
  end

  [
    429,
    { "Content-Type" => "application/json" },
    [ error_payload.to_json ]
  ]
end
