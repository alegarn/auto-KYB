require 'rails_helper'

RSpec.describe 'Forms authorization', type: :request do
  let!(:owner) { User.create!(email: 'owner@example.com', password: 'password') }
  let!(:other) { User.create!(email: 'other@example.com', password: 'password') }
  let!(:form) { owner.forms.create!(name: 'Owner Form') }

  around do |example|
    orig = Current.session
    Current.session = Struct.new(:user, :id).new(owner, SecureRandom.uuid)
    example.run
    Current.session = orig
  end

  it 'prevents other users from accessing a form' do
    # act as other
    Current.session = Struct.new(:user, :id).new(other, SecureRandom.uuid)

    get "/forms/#{form.id}"

    expect(response).to have_http_status(:not_found)
  end
end
