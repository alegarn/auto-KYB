FactoryBot.define do
  factory :client_form do
    association :client
    association :form

    status { 0 }
    password_digest { BCrypt::Password.create('secret') }
    access_token { SecureRandom.hex(16) }
    expires_at { 7.days.from_now }
  end
end
