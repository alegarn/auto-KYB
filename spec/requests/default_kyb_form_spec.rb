require 'rails_helper'

RSpec.describe "Default KYB Form initialization", type: :model do
  it "creates a default KYB form when a new user registers" do
    email = "newuser@example.com"
    user = User.create!(email: email, password: 'a_secure_password_123', subscription_status: 'active')

    form = user.forms.find_by(name: 'Default KYB Form')
    expect(form).not_to be_nil

    labels = form.form_fields.pluck(:label)
    expect(labels).to include('Full Legal Name', 'Date of Birth', 'Nationality', 'Residential Address')

    field_types = form.form_fields.pluck(:field_type)
    expect(field_types).to include('text', 'email')

    required = form.form_fields.where(required: true).pluck(:label)
    expect(required).to include('Full Legal Name', 'Date of Birth', 'Nationality', 'Residential Address')
  end
end
