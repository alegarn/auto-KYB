class FormInitializer
  DEFAULT_KYB = {
    name: "Default KYB Form",
    fields: [
      { label: "Company Name", field_type: "text", required: true, position: 1 },
      { label: "Registration Number", field_type: "text", required: true, position: 2 },
      { label: "Business Address", field_type: "text", required: true, position: 3 },
      { label: "Contact", field_type: "email", required: true, position: 4 }
    ]
  }.freeze

  def self.default_for_user(user)
    form = user.forms.create!(name: DEFAULT_KYB[:name], structure: { fields: DEFAULT_KYB[:fields] })
    DEFAULT_KYB[:fields].each do |f|
      form.form_fields.create!(label: f[:label], field_type: f[:field_type], required: f[:required], position: f[:position])
    end
    form
  end
end
