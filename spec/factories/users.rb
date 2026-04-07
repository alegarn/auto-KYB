FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'a_secure_password_123' }
    crm_auto_sync_on_portal_submit { true }
    verified { false }
    subscription_status { 'active' }
    onboarding_completed { false }
    subscription_canceled_at { nil }

    trait :incomplete do
      subscription_status { 'incomplete' }
    end

    trait :verified do
      verified { true }
    end

    trait :subscribed do
      subscription_status { 'active' }
      verified { true }
    end

    trait :trialing do
      subscription_status { 'trialing' }
      verified { true }
    end

    trait :canceled do
      subscription_status { 'canceled' }
      subscription_canceled_at { Time.current }
    end

    trait :canceled_over_a_year_ago do
      subscription_status { 'canceled' }
      subscription_canceled_at { 13.months.ago }
    end
  end
end
