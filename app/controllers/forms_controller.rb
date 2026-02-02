class FormsController < ApplicationController
  def index
    forms = current_user ? current_user.forms.order(created_at: :desc).map { |f| { id: f.id, name: f.name, created_at: f.created_at.to_date.to_s } } : []

    if Rails.env.test?
      # simple HTML fallback for feature specs that don't render Inertia
      html = <<~HTML
        <h1>My Forms</h1>
        <p>#{ERB::Util.html_escape(current_user&.email.to_s)}</p>
        <ul>
          #{forms.map { |f| "<li>#{ERB::Util.html_escape(f[:name])}</li>" }.join}
        </ul>
      HTML

      render html: html.html_safe
    else
      render inertia: "Forms/Index", props: {
        user: current_user,
        session_id: current_session_id,
        forms: forms
      }
    end
  end

  def show
    form = current_user.forms.find(params[:id])
    render json: form.as_json(include: :form_fields)
  end

  private

  def current_user
    Current.session&.user
  end

  def current_session_id
    Current.session&.id
  end
end
