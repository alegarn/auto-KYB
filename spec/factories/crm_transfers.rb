FactoryBot.define do
  factory :crm_transfer do
    association :client
    association :crm_connection

    status { 'pending' }
    transferred_at { nil }
    error_message { nil }
  end
end
