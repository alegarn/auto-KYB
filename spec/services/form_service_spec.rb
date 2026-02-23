require 'rails_helper'

RSpec.describe FormService do
  describe '.create_form' do
    it 'creates a form and its fields' do
      user = User.create!(email: 'svc1@example.com', password: 'securepassword123')
      params = { name: 'Svc Form', structure: { fields: [ { label: 'Name', field_type: 'text', required: true } ] } }

      form = FormService.create_form(user, params)

      expect(form).to be_persisted
      expect(form.form_fields.count).to eq(1)
      expect(form.form_fields.first.label).to eq('Name')
    end

    it 'raises DuplicateExportKeysError when effective export keys are duplicated' do
      user = User.create!(email: 'svc1_dup@example.com', password: 'securepassword123')
      params = {
        name: 'Dup Export Keys',
        structure: {
          fields: [
            { label: 'Company Name', field_type: 'text', metadata: { export_key: 'company_name' } },
            { label: 'Legal Name', field_type: 'text', metadata: { export_key: 'company_name' } }
          ]
        }
      }

      expect {
        FormService.create_form(user, params)
      }.to raise_error(FormService::DuplicateExportKeysError)
    end
  end

  describe '.update_form' do
    it 'updates form name and structure' do
      user = User.create!(email: 'svc2@example.com', password: 'securepassword123')
      form = user.forms.create!(name: 'Old')
      params = { name: 'New', structure: { fields: [ { label: 'Email', field_type: 'text' } ] } }

      updated = FormService.update_form(user, form, params)

      expect(updated.name).to eq('New')
      expect(updated.form_fields.count).to eq(1)
    end

    it 'raises DataLossWarning when removing field with submissions' do
      user = User.create!(email: 'svc3@example.com', password: 'securepassword123')
      form = user.forms.create!(name: 'WithField')
      form.form_fields.create!(label: 'ToRemove', field_type: 'text')

      # stub Form.has_submissions_for_field? using singleton class if method missing
      if Form.respond_to?(:has_submissions_for_field?)
        allow(Form).to receive(:has_submissions_for_field?).with(form.id, 'ToRemove').and_return(true)
      else
        class << Form

          def has_submissions_for_field?(_form_id, _field_label)
            false
          end

        end
        allow(Form).to receive(:has_submissions_for_field?).with(form.id, 'ToRemove').and_return(true)
      end

      params = { structure: { fields: [] } }

      expect { FormService.update_form(user, form, params) }.to raise_error(FormService::DataLossWarning)
    end

    it 'raises DuplicateExportKeysError when labels collide without explicit export keys' do
      user = User.create!(email: 'svc2_dup@example.com', password: 'securepassword123')
      form = user.forms.create!(name: 'Update Dup')

      params = {
        structure: {
          fields: [
            { label: 'Field Name', field_type: 'text' },
            { label: 'Field Name', field_type: 'email' }
          ]
        }
      }

      expect {
        FormService.update_form(user, form, params)
      }.to raise_error(FormService::DuplicateExportKeysError)
    end
  end

  describe '.delete_form' do
    it 'deletes owned form' do
      user = User.create!(email: 'svc4@example.com', password: 'securepassword123')
      form = user.forms.create!(name: 'ToDelete')

      expect { FormService.delete_form(user, form) }.to change { Form.count }.by(-1)
    end

    it 'raises when deleting another users form' do
      user1 = User.create!(email: 'svc5a@example.com', password: 'securepassword123')
      user2 = User.create!(email: 'svc5b@example.com', password: 'securepassword123')
      form = user1.forms.create!(name: 'Other')

      expect { FormService.delete_form(user2, form) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
