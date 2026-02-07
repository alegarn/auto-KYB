class FormsController < ApplicationController
  def index
    forms = if current_user
      FormSerializer.collection(current_user.forms.order(created_at: :desc))
    else
      []
    end

    render inertia: 'forms/index', props: {
      user: current_user ? { id: current_user.id, email: current_user.email } : nil,
      session_id: current_session_id,
      forms: forms
    }
  end

  def show
    form = current_user.forms.find(params[:id])
    detail = FormDetailSerializer.new(form).as_json

    render inertia: 'forms/show', props: {
      user: current_user ? { id: current_user.id, email: current_user.email } : nil,
      session_id: current_session_id,
      form: detail
    }
  end

  def new
    render inertia: 'forms/new', props: {
      user: current_user ? { id: current_user.id, email: current_user.email } : nil,
      session_id: current_session_id
    }
  end

  def create
    created = FormService.create_form(current_user, form_params.to_h)

    redirect_to forms_path, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    render inertia: 'forms/new', props: {
      user: current_user ? { id: current_user.id, email: current_user.email } : nil,
      session_id: current_session_id,
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def edit
    form = current_user.forms.find(params[:id])

    render inertia: 'forms/edit', props: {
      session_id: current_session_id,
      form: FormDetailSerializer.new(form).as_json
    }
  end

  def destroy
    form = current_user.forms.find(params[:id])

    form.destroy!

    redirect_to forms_path, status: :see_other
  end

  def update
    form = current_user.forms.find(params[:id])
    updated = FormService.update_form(current_user, form, form_params.to_h)

    redirect_to form_path(form), notice: 'Form updated'
  rescue FormService::DataLossWarning => e
    render inertia: 'forms/edit', props: {
      session_id: current_session_id,
      form: FormDetailSerializer.new(form).as_json,
      error: e.message
    }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render inertia: 'forms/edit', props: {
      session_id: current_session_id,
      form: form.present? ? FormDetailSerializer.new(form).as_json : nil,
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  private

  def form_params
    base = params.require(:form).permit(:name, :description)
    if params[:form][:structure].present?
      raw = params[:form][:structure]
      base[:structure] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    end
    base
  end
end
