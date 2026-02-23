require 'rails_helper'

RSpec.describe 'Forms Duplicate', type: :request do
  let!(:user) { create(:user) }
  let!(:form) do
    FormService.create_form(user, {
      name: 'My Form',
      structure: {
        fields: [
          { label: 'Name', field_type: 'text', required: true, position: 1 }
        ]
      }
    })
  end

  let(:session_record) { user.sessions.create! }
  let(:headers) { { 'Cookie' => "session_token=#{session_record.id}" } }

  describe 'POST /forms/:id/duplicate' do
    it 'duplicates the form and redirects to the index page' do
      existing_ids = Form.pluck(:id)

      expect {
        post duplicate_form_path(form), headers: headers
      }.to change(Form, :count).by(1)

      created_ids = Form.pluck(:id) - existing_ids
      expect(created_ids.size).to eq(1)

      new_form = Form.find(created_ids.first)
      expect(new_form.user_id).to eq(user.id)
      expect(new_form.name).to eq('My Form (1)')
      expect(new_form.form_fields.count).to eq(1)

      expect(response).to redirect_to(forms_path)
      expect(flash[:inertia][:toast][:message]).to eq('Form duplicated successfully')
    end

    it 'returns 404 if the form belongs to another user' do
      other_user = create(:user)
      other_form = FormService.create_form(other_user, { name: 'Other Form', structure: {} })

      expect {
        post duplicate_form_path(other_form), headers: headers
      }.not_to change(Form, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
