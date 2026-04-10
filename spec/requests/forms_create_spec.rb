require 'rails_helper'

RSpec.describe "Forms Create", type: :request do
  it "creates a form via POST and persists structure" do
    user = FactoryBot.create(:user, :subscribed)
    session_record = user.sessions.create!

    params = {
      form: {
        name: 'Customer Info',
        structure: { fields: [ { label: 'Full Name', field_type: 'text', required: true } ] }
      }
    }

    headers = { 'Cookie' => "session_token=#{session_record.id}" }

    post "/forms", params: params, headers: headers

    user.reload

    form = user.forms.find_by(name: 'Customer Info')
    expect(form).not_to be_nil
    expect(form.form_fields.count).to eq(1)
    expect(form.form_fields.first.label).to eq('Full Name')
    expect(form.structure['fields'].first['label']).to eq('Full Name')
  end

  it "returns unprocessable entity when export mapping keys are duplicated" do
    user = FactoryBot.create(:user, :subscribed)
    session_record = user.sessions.create!

    params = {
      form: {
        name: 'Customer Info',
        structure: {
          fields: [
            { label: 'Company Name', field_type: 'text', metadata: { export_key: 'company_name' } },
            { label: 'Legal Name', field_type: 'text', metadata: { export_key: 'company_name' } }
          ]
        }
      }
    }

    headers = { 'Cookie' => "session_token=#{session_record.id}" }

    post "/forms", params: params, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
