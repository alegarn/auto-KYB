class FormsController < ApplicationController
  def index
    forms = if current_user
      FormSerializer.collection(current_user.forms.order(created_at: :desc))
    else
      []
    end

    if request.format.html?
      render :index, locals: { forms: forms, user: current_user }
    else
      render inertia: 'Forms/Index', props: {
        user: current_user ? { id: current_user.id, email: current_user.email } : nil,
        session_id: current_session_id,
        forms: forms
      }
    end
  end

  def show
    form = current_user.forms.find(params[:id])
    detail = FormDetailSerializer.new(form).as_json

    if request.format.html?
      # Render a minimal HTML preview for feature specs (Capybara) so tests can assert
      html = "<h1>#{ERB::Util.html_escape(detail[:name])}</h1>"
      html << "<p>#{ERB::Util.html_escape(detail[:description] || '')}</p>"
      detail[:form_fields].each do |f|
        label_text = f[:label].to_s + (f[:required] ? '*' : '')
        html << "<div><label for=\"field_#{f[:id]}\">#{ERB::Util.html_escape(label_text)}</label>"
        html << "<input id=\"field_#{f[:id]}\" name=\"field_#{f[:id]}\" />"
        html << '</div>'
      end
      html << '<button type="button">Submit Preview</button>'
      html << "<a href=\"/forms/#{form.id}/edit\">Edit</a>"
      render html: html.html_safe
    else
      render json: detail
    end
  end

  def new
    if request.format.html?
      render :new, locals: { user: current_user }
    else
      render inertia: 'Forms/New', props: { user: current_user ? { id: current_user.id, email: current_user.email } : nil }
    end
  end

  def create
    # convert permitted params to plain hash for service layer
    created = FormService.create_form(current_user, form_params.to_h)
    redirect_to forms_path, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    if request.format.html?
      render :new, locals: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    else
      render inertia: 'Forms/New', props: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def edit
    form = current_user.forms.find(params[:id])
    if request.format.html?
      render :edit, locals: { form: form }
    else
      render inertia: 'Forms/Edit', props: { form: FormDetailSerializer.new(form).as_json }
    end
  end

  def destroy
    form = current_user.forms.find(params[:id])

    form.destroy!

    if request.format.html?
      redirect_to forms_path, status: :see_other
    else
      head :no_content
    end
  end

  def update
    form = current_user.forms.find(params[:id])
    updated = FormService.update_form(current_user, form, form_params.to_h)

    if request.format.html?
      redirect_to form_path(form), notice: 'Form updated'
    else
      render json: FormDetailSerializer.new(updated).as_json
    end
  rescue FormService::DataLossWarning => e
    if request.format.html?
      redirect_to edit_form_path(form), alert: e.message
    else
      render json: { error: e.message }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    if request.format.html?
      render :edit, locals: { form: form, errors: e.record.errors.full_messages }, status: :unprocessable_entity
    else
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def current_user
    Current.session&.user
  end

  def current_session_id
    Current.session&.id
  end

  def form_params
    params.require(:form).permit(:name, :description, structure: { fields: [ :label, :field_type, :required, :position, metadata: {} ] })
  end
end
