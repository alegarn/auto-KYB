FactoryBot.define do
  factory :crm_transfer do
    association :client
    association :crm_connection

    status { CrmTransfer::STATUS_PENDING }
    trigger { CrmTransfer::TRIGGER_MANUAL_EXPORT }
    failure_kind { nil }
    attempts_count { 0 }
    last_attempt_at { nil }
    request_context { {} }
    transferred_at { nil }
    error_message { nil }

    trait :manual_export do
      trigger { CrmTransfer::TRIGGER_MANUAL_EXPORT }
    end

    trait :portal_submit do
      trigger { CrmTransfer::TRIGGER_PORTAL_SUBMIT }
    end

    trait :client_create_sync do
      trigger { CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC }
    end

    trait :data_import do
      trigger { CrmTransfer::TRIGGER_DATA_IMPORT }
      direction { "import" }
      status { CrmTransfer::STATUS_SUCCESS }
      transferred_at { Time.current }
    end

    trait :processing do
      status { CrmTransfer::STATUS_PROCESSING }
      attempts_count { 1 }
      last_attempt_at { Time.current }
    end

    trait :success do
      status { CrmTransfer::STATUS_SUCCESS }
      attempts_count { 1 }
      last_attempt_at { Time.current }
      transferred_at { Time.current }
    end

    trait :failed do
      status { CrmTransfer::STATUS_FAILED }
      failure_kind { CrmTransfer::FAILURE_KIND_PROVIDER_ERROR }
      error_message { "Provider request failed" }
      attempts_count { 1 }
      last_attempt_at { Time.current }
    end

    trait :retryable_failed do
      failed
      failure_kind { CrmTransfer::FAILURE_KIND_PROVIDER_ERROR }
    end

    trait :non_retryable_failed do
      failed
      failure_kind { CrmTransfer::FAILURE_KIND_AUTHENTICATION_ERROR }
    end
  end
end
