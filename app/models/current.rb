class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :client_form
  attribute :user_agent, :ip_address

  delegate :user, to: :session, allow_nil: true
end
