FactoryBot.define do
  factory :client do
    association :user

    name { "John Doe" }
    company_name { "Acme Corporation" }
    email { "john.doe@example.com" }
    phone { "+1 (555) 123-4567" }
    address { { street: "123 Main St", city: "New York", country: "USA" } }

    trait :invalid do
      name { nil }
      company_name { nil }
    end

    trait :without_email do
      email { nil }
    end

    trait :without_phone do
      phone { nil }
    end

    trait :with_invalid_email do
      email { "invalid-email" }
    end

    trait :with_invalid_phone do
      phone { "123" }
    end
  end
end
