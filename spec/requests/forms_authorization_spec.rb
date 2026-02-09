require 'rails_helper'

RSpec.describe 'Forms authorization', type: :request do
  let!(:owner) { FactoryBot.create(:user, password: 'securepassword123') }
  let!(:other) { FactoryBot.create(:user, password: 'securepassword123') }
  let!(:form) { FormService.create_form(owner, { name: 'Owner Form', structure: { fields: [] } }) }

  it 'prevents other users from accessing a form' do
    sign_in_user(other)
    session_id = other.sessions.last.id

    get "/forms/#{form.id}", headers: { 'Cookie' => "session_token=#{session_id}" }

    expect(response).to have_http_status(:not_found)
  end
end
