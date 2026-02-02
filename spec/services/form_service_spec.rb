require 'rails_helper'

RSpec.describe FormService do
  let(:user) do
    # ensure factory creation does not trigger default form initialization for these unit tests
    if User._create_callbacks.select { |cb| cb.kind == :after && cb.filter == :initialize_default_forms }.any?
      User.skip_callback(:create, :after, :initialize_default_forms)
      u = FactoryBot.create(:user)
      User.set_callback(:create, :after, :initialize_default_forms)
      u
    else
      FactoryBot.create(:user)
    end
  end

  describe '.initialize_default_for_user' do
    it 'creates a default form for new user' do
      expect { FormService.initialize_default_for_user(user) }.to change { user.forms.count }.by(1)
    end

    it 'is idempotent and does not create duplicate default forms' do
      FormService.initialize_default_for_user(user)
      expect { FormService.initialize_default_for_user(user) }.not_to change { user.forms.count }
    end
  end

  describe '.create_form' do
    it 'creates a form with provided structure and fields' do
      params = { name: 'My Form', structure: { fields: [ { label: 'A', field_type: 'text', required: true } ] } }
      form = FormService.create_form(user, params)
      expect(form).to be_persisted
      expect(form.form_fields.count).to eq(1)
    end
  end

  describe '.update_form' do
    it 'updates form name and structure' do
      form = FormService.create_form(user, { name: 'Old', structure: { fields: [] } })
      updated = FormService.update_form(user, form, { name: 'New', structure: { fields: [ { label: 'X', field_type: 'text' } ] } })
      expect(updated.name).to eq('New')
      expect(updated.form_fields.count).to eq(1)
    end
  end

  describe '.delete_form' do
    it 'deletes the form belonging to the user' do
      form = FormService.create_form(user, { name: 'ToDelete', structure: { fields: [] } })
      expect { FormService.delete_form(user, form) }.to change { user.forms.count }.by(-1)
    end
  end
end
