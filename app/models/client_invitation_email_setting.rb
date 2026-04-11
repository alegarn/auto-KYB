class ClientInvitationEmailSetting < ApplicationRecord

  ALLOWED_PLACEHOLDERS = %w[{{client_name}} {{client_email}} {{form_name}} {{invite_link}} {{password}}].freeze
  REQUIRED_PLACEHOLDERS_FOR_AUTO_SEND = %w[{{invite_link}} {{password}}].freeze
  PLACEHOLDER_PATTERN = /\{\{[a-z_]+\}\}/

  belongs_to :user

  validates :subject_template, length: { maximum: 500 }, allow_blank: true
  validates :body_template, length: { maximum: 5000 }, allow_blank: true
  validate :subject_template_uses_allowed_placeholders
  validate :body_template_uses_allowed_placeholders
  validate :subject_template_has_no_newlines
  validate :required_placeholders_when_auto_send

  private

  def subject_template_uses_allowed_placeholders
    validate_placeholders(:subject_template)
  end

  def body_template_uses_allowed_placeholders
    validate_placeholders(:body_template)
  end

  def validate_placeholders(attribute)
    value = public_send(attribute)
    return if value.blank?

    found = value.scan(PLACEHOLDER_PATTERN)
    unknown = found - ALLOWED_PLACEHOLDERS
    if unknown.any?
      errors.add(attribute, "contains unknown variables: #{unknown.join(', ')}")
    end
  end

  def subject_template_has_no_newlines
    return if subject_template.blank?

    if subject_template.match?(/[\r\n]/)
      errors.add(:subject_template, "must not contain line breaks")
    end
  end

  def required_placeholders_when_auto_send
    return unless auto_send?

    REQUIRED_PLACEHOLDERS_FOR_AUTO_SEND.each do |placeholder|
      unless body_template.to_s.include?(placeholder)
        errors.add(:body_template, "must include #{placeholder} when automatic send is enabled")
      end
    end
  end

end
