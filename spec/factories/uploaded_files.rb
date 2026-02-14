FactoryBot.define do
  factory :uploaded_file do
    association :client
    association :form_response

    field_key { SecureRandom.uuid }
    status { "available" }
    uploaded_at { Time.current }

    trait :downloaded do
      status { "downloaded" }
      downloaded_at { Time.current }
    end

    trait :replaced do
      status { "replaced" }
      deleted_at { Time.current }
    end

    trait :purged do
      status { "purged" }
    end

    trait :with_file do
      after(:create) do |uploaded_file|
        uploaded_file.file.attach(
          io: StringIO.new("test file content"),
          filename: "test.pdf",
          content_type: "application/pdf"
        )
      end
    end
  end
end
