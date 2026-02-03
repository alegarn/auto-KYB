class FormSerializer
  def initialize(form)
    @form = form
  end

  def as_json(*)
    {
      id: @form.id,
      name: @form.name,
      created_at: @form.created_at.to_date.to_s,
      updated_at: @form.updated_at.to_date.to_s,
    }
  end

  def self.collection(forms)
    forms.map { |f| new(f).as_json }
  end
end
