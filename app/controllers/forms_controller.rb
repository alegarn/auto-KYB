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
      render inertia: "Forms/Index", props: {
        user: current_user ? { id: current_user.id, email: current_user.email } : nil,
        session_id: current_session_id,
        forms: forms
      }
    end
  end

  def show
    form = current_user.forms.find(params[:id])
    render json: FormDetailSerializer.new(form).as_json
  end

  def new
    if request.format.html?
      render :new, locals: { user: current_user }
    else
      render inertia: "Forms/New", props: { user: current_user ? { id: current_user.id, email: current_user.email } : nil }
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
      render inertia: "Forms/New", props: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
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
    params.require(:form).permit(:name, :description, structure: { fields: [:label, :field_type, :required, :position, metadata: {}] })
  end
end
