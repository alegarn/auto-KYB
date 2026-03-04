FactoryBot.define do
  factory :crm_client_link do
    client { nil }
    crm_connection { nil }
    external_contact_id { "MyString" }
    external_company_id { "MyString" }
  end
end
