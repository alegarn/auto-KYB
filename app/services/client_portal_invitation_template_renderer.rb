class ClientPortalInvitationTemplateRenderer

  ALLOWED_PLACEHOLDERS = ClientInvitationEmailSetting::ALLOWED_PLACEHOLDERS
  PLACEHOLDER_PATTERN = ClientInvitationEmailSetting::PLACEHOLDER_PATTERN

  DEFAULT_SUBJECT = "Your Quick KYB secure form access"
  DEFAULT_BODY = <<~BODY.strip
    Hello {{client_name}},

    You have been invited to fill out the {{form_name}} form on Quick KYB.

    Access your portal here: {{invite_link}}

    Your portal password: {{password}}

    Please keep these credentials safe, as the password is shown only once.
  BODY

  Result = Struct.new(:subject, :body, :errors, keyword_init: true) do
    def success?
      errors.blank?
    end
  end

  def self.render(subject_template: nil, body_template: nil, variables: {})
    new(subject_template: subject_template, body_template: body_template, variables: variables).render
  end

  def initialize(subject_template: nil, body_template: nil, variables: {})
    @subject_template = subject_template.presence || DEFAULT_SUBJECT
    @body_template = body_template.presence || DEFAULT_BODY
    @variables = variables.stringify_keys
  end

  def render
    errors = []
    errors.concat(validate_placeholders(@subject_template, "subject"))
    errors.concat(validate_placeholders(@body_template, "body"))

    return Result.new(errors: errors) if errors.any?

    subject = interpolate(@subject_template)
    body = interpolate(@body_template)

    # Strip newlines from subject to prevent header injection
    subject = subject.gsub(/[\r\n]/, " ").strip

    Result.new(subject: subject, body: body)
  end

  private

  def validate_placeholders(template, label)
    found = template.scan(PLACEHOLDER_PATTERN)
    unknown = found - ALLOWED_PLACEHOLDERS
    unknown.map { |token| "#{label} contains unknown variable: #{token}" }
  end

  def interpolate(template)
    template.gsub(PLACEHOLDER_PATTERN) do |match|
      key = match.delete("{}") # e.g., "client_name"
      @variables.fetch(key, match)
    end
  end

end
