class ClientPortalInvitationDeliveryService

  Result = Struct.new(:success, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def self.call(client_form:, password:, user:)
    new(client_form: client_form, password: password, user: user).call
  end

  def initialize(client_form:, password:, user:)
    @client_form = client_form
    @password = password
    @user = user
  end

  def call
    client = @client_form.client

    return Result.new(success: false, error: "Client has no email address") if client.email.blank?
    return Result.new(success: false, error: "Password is no longer available") if @password.blank?

    setting = @user.client_invitation_email_setting
    renderer_result = ClientPortalInvitationTemplateRenderer.render(
      subject_template: setting&.subject_template,
      body_template: setting&.body_template,
      variables: template_variables(client)
    )

    return Result.new(success: false, error: renderer_result.errors.join(", ")) unless renderer_result.success?

    ClientPortalInvitationMailer.with(
      recipient_email: client.email,
      client_name: client.name,
      form_name: @client_form.form.name,
      invite_link: invite_link,
      password: @password,
      rendered_subject: renderer_result.subject,
      rendered_body: renderer_result.body
    ).portal_access.deliver_now

    @client_form.update!(
      invitation_emailed_at: Time.current,
      invitation_emailed_to: client.email
    )

    Result.new(success: true)
  rescue StandardError => e
    Rails.logger.error("ClientPortalInvitationDeliveryService failed: #{e.message}")
    Result.new(success: false, error: "Failed to send the invitation email. Please try again.")
  end

  private

  def invite_link
    Rails.application.routes.url_helpers.client_portal_login_url(
      @client_form.access_token,
      **ActionMailer::Base.default_url_options
    )
  end

  def template_variables(client)
    {
      "client_name" => client.name.to_s,
      "client_email" => client.email.to_s,
      "form_name" => @client_form.form.name.to_s,
      "invite_link" => invite_link,
      "password" => @password
    }
  end

end
