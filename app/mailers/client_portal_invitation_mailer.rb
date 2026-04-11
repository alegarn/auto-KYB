class ClientPortalInvitationMailer < ApplicationMailer

  def portal_access
    @client_name = params[:client_name]
    @invite_link = params[:invite_link]
    @password = params[:password]
    @form_name = params[:form_name]
    @rendered_subject = params[:rendered_subject]
    @rendered_body = params[:rendered_body]

    mail(
      to: params[:recipient_email],
      subject: @rendered_subject
    )
  end

end
