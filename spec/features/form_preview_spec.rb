require 'rails_helper'

RSpec.describe "Form Preview", type: :request do
  it "returns ordered fields and required flags" do
    user = sign_in_user

    form = FactoryBot.create(:form, user: user)
    FactoryBot.create(:form_field, form: form, label: "Address", position: 1, required: true)
    FactoryBot.create(:form_field, form: form, label: "City", position: 2, required: false)

    get form_path(form), params: { format: :json }

    expect(response).to have_http_status(:success)
    payload = JSON.parse(response.body)
    labels = payload['form_fields'].map { |f| f['label'] }
    required_map = payload['form_fields'].map { |f| [ f['label'], f['required'] ] }.to_h

    expect(labels).to eq([ "Address", "City" ])
    expect(required_map["Address"]).to be true
    expect(required_map["City"]).to be false
  end
end
