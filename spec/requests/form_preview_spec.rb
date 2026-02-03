require 'rails_helper'

RSpec.describe "Form Preview API", type: :request do
  it "returns form detail with fields" do
    user = sign_in_user
    form = FactoryBot.create(:form, user: user)
    ff = FactoryBot.create(:form_field, form: form, label: 'Address', position: 1, required: true)

    get "/forms/#{form.id}"

    expect(response).to have_http_status(:success)
    json = JSON.parse(response.body)
    expect(json['id']).to eq(form.id)
    expect(json['form_fields']).to be_an(Array)
    expect(json['form_fields'].map { |f| f['label'] }).to include('Address')
  end
end
