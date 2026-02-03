class FormDetailSerializer
  def initialize(form)
    @form = form
  end

  def as_json(*)
    {
      id: @form.id,
      name: @form.name,
      structure: @form.structure,
      created_at: @form.created_at.iso8601,
      form_fields: serialized_fields
    }
  end

  private

  def serialized_fields
    @form.form_fields.order(:position).map do |ff|
      {
        id: ff.id,
        label: ff.label,
        field_type: ff.field_type,
        required: ff.required,
        position: ff.position,
        metadata: ff.metadata || {}
      }
    end
  end
end
