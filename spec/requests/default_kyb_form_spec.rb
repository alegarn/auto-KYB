require 'rails_helper'

RSpec.describe "Default KYB Form initialization", type: :request do
  it "creates a default KYB form when a new user registers" do
    email = "newuser@example.com"
    post sign_up_path, params: { email: email, password: 'a_secure_password_123', password_confirmation: 'a_secure_password_123' }

    user = User.find_by(email: email)
    expect(user).not_to be_nil

    form = user.forms.find_by(name: 'Default KYB Form')
    expect(form).not_to be_nil

    labels = form.form_fields.pluck(:label)
    expect(labels).to include('Company Name', 'Registration Number', 'Business Address', 'Contact')

    field_types = form.form_fields.pluck(:field_type)
    expect(field_types).to include('text', 'email')

    required = form.form_fields.where(required: true).pluck(:label)
    expect(required).to include('Company Name', 'Registration Number', 'Business Address', 'Contact')
  end
end
