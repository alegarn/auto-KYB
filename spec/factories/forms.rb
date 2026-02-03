FactoryBot.define do
  factory :form do
    association :user
    name { "Test Form" }
    structure { { fields: [] } }
  end

  factory :form_field do
    association :form
    label { "Field" }
    field_type { "text" }
    required { false }
    position { 1 }
    metadata { {} }
  end
end
