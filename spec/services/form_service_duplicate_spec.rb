require 'rails_helper'

RSpec.describe FormService do
  describe '.duplicate_form' do
    let(:user) { create(:user) }
    let(:form) do
      create(:form, user: user, name: 'My Form', structure: { settings: { title: 'Main' } }).tap do |f|
        create(:form_field, form: f, label: 'Name', field_type: 'text', required: true, position: 1)
        create(:form_field, form: f, label: 'Email', field_type: 'email', required: false, position: 2)
      end
    end

    it 'duplicates the form with a new name' do
      new_form = FormService.duplicate_form(user, form)

      expect(new_form).to be_persisted
      expect(new_form.id).not_to eq(form.id)
      expect(new_form.name).to eq('My Form (1)')
      expect(new_form.form_fields.count).to eq(2)
      expect(new_form.user_id).to eq(user.id)
      expect(new_form.structure['settings']).to eq(form.structure['settings'])

      fields = new_form.form_fields.order(:position)
      expect(fields.map(&:label)).to eq([ 'Name', 'Email' ])
      expect(fields.map(&:field_type)).to eq([ 'text', 'email' ])
      expect(fields.map(&:required)).to eq([ true, false ])
    end

    it 'increments the counter if duplicates already exist' do
      FormService.duplicate_form(user, form) # Creates "My Form (1)"
      new_form2 = FormService.duplicate_form(user, form)

      expect(new_form2.name).to eq('My Form (2)')
    end

    it 'strips existing counter from the base name' do
      new_form = FormService.duplicate_form(user, form)
      new_form2 = FormService.duplicate_form(user, new_form)

      expect(new_form2.name).to eq('My Form (2)')
    end

    it 'raises an error if the form belongs to another user' do
      other_user = create(:user)

      expect {
        FormService.duplicate_form(other_user, form)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
