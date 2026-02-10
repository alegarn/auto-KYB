require 'rails_helper'

RSpec.describe "Forms Delete", type: :request do
  it 'deletes form via DELETE' do
    user = sign_in_user
    session_id = user.sessions.last.id
    form = FormService.create_form(user, { name: 'ToDelete', structure: { fields: [] } })

    delete "/forms/#{form.id}", headers: { 'Cookie' => "session_token=#{session_id}" }, as: :json
    Rails.logger.info "[TEST DEBUG] response.status=#{response.status} body=#{response.body.inspect}"

    expect(response).to have_http_status(:no_content)
    expect { Form.find(form.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
