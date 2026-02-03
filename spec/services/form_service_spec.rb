require 'rails_helper'

RSpec.describe FormService do
  describe '.create_form' do
    it 'creates a form and its fields' do
      user = User.create!(email: 'svc1@example.com', password: 'password')
      params = { name: 'Svc Form', structure: { fields: [{ label: 'Name', field_type: 'text', required: true }] } }

      form = FormService.create_form(user, params)

      expect(form).to be_persisted
      expect(form.form_fields.count).to eq(1)
      expect(form.form_fields.first.label).to eq('Name')
    end
  end

  describe '.update_form' do
    it 'updates form name and structure' do
      user = User.create!(email: 'svc2@example.com', password: 'password')
      form = user.forms.create!(name: 'Old')
      params = { name: 'New', structure: { fields: [{ label: 'Email', field_type: 'text' }] } }

      updated = FormService.update_form(user, form, params)

      expect(updated.name).to eq('New')
      expect(updated.form_fields.count).to eq(1)
    end

    it 'raises DataLossWarning when removing field with submissions' do
      user = User.create!(email: 'svc3@example.com', password: 'password')
      form = user.forms.create!(name: 'WithField')
      ff = form.form_fields.create!(label: 'ToRemove', field_type: 'text')

      # stub Form.has_submissions_for_field?
      allow(Form).to receive(:has_submissions_for_field?).with(form.id, 'ToRemove').and_return(true)

      params = { structure: { fields: [] } }

      expect { FormService.update_form(user, form, params) }.to raise_error(FormService::DataLossWarning)
    end
  end

  describe '.delete_form' do
    it 'deletes owned form' do
      user = User.create!(email: 'svc4@example.com', password: 'password')
      form = user.forms.create!(name: 'ToDelete')

      expect { FormService.delete_form(user, form) }.to change { Form.count }.by(-1)
    end

    it 'raises when deleting another users form' do
      user1 = User.create!(email: 'svc5a@example.com', password: 'password')
      user2 = User.create!(email: 'svc5b@example.com', password: 'password')
      form = user1.forms.create!(name: 'Other')

      expect { FormService.delete_form(user2, form) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
