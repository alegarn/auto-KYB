class FormsController < ApplicationController

  def index
    forms = current_user ? FormSerializer.collection(current_user.forms.order(created_at: :desc)) : []

    render inertia: "forms/index", props: default_inertia_props.merge(forms: forms)
  end

  def show
    form = current_user.forms.find(params[:id])
    detail = FormDetailSerializer.new(form).as_json
    respond_to do |format|
      format.json { render json: detail, status: :ok }
      format.html { render inertia: "forms/show", props: default_inertia_props.merge(form: detail) }
    end
  end

  def new
    render inertia: "forms/new", props: default_inertia_props
  end

  def create
    FormService.create_form(current_user, form_params.to_h)
    redirect_to forms_path, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    render inertia: "forms/new", props: default_inertia_props.merge(
      errors: e.record.errors.full_messages
    ), status: :unprocessable_entity
  end

  def edit
    form = current_user.forms.find(params[:id])

    render inertia: "forms/edit", props: {
      session_id: current_session_id,
      form: FormDetailSerializer.new(form).as_json
    }
  end

  def destroy
    form = current_user.forms.find(params[:id])
    form.destroy!
    respond_to do |format|
      format.json { head :no_content }
      format.html do
        forms = FormSerializer.collection(current_user.forms.order(created_at: :desc))
        render inertia: "forms/index", props: default_inertia_props.merge(forms: forms)
      end
    end
  end

  def update
    form = current_user.forms.find(params[:id])
    FormService.update_form(current_user, form, form_params.to_h)
    respond_to do |format|
      format.json { render json: FormDetailSerializer.new(form).as_json, status: :ok }
      format.html do
        render inertia: "forms/show", props: default_inertia_props.merge(form: FormDetailSerializer.new(form).as_json)
      end
    end
  rescue FormService::DataLossWarning => e
    render inertia: "forms/edit", props: {
      session_id: current_session_id,
      form: FormDetailSerializer.new(form).as_json,
      error: e.message
    }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render inertia: "forms/edit", props: {
      session_id: current_session_id,
      form: form ? FormDetailSerializer.new(form).as_json : nil,
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  private

  def form_params
    params.require(:form).permit(
      :name,
      :description,
      structure: {
        settings: {},
        fields: [ :id, :label, :field_type, :required, :position, { metadata: {} } ]
      }
    )
  end

end
