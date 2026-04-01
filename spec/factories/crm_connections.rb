FactoryBot.define do
  factory :crm_connection do
    association :user
    provider { "hubspot" }
    access_token { "token" }
    refresh_token { "refresh" }
    expires_at { 1.hour.from_now }
    status { "active" }
  end
end
