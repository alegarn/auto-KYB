require 'rails_helper'

RSpec.describe "Forms Delete", type: :request do
  it 'deletes form via DELETE' do
    user = sign_in_user
    form = FormService.create_form(user, { name: 'ToDelete', structure: { fields: [] } })

    expect {
      delete "/forms/#{form.id}", as: :json
    }.to change { Form.count }.by(-1)

    expect(response).to have_http_status(:no_content)
    expect { Form.find(form.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
