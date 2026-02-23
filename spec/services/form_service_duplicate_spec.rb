require 'rails_helper'

RSpec.describe FormService do
  describe '.duplicate_form' do
    let(:user) { User.create!(email: 'test@example.com', password: 'securepassword123') }
    let(:form) do
      FormService.create_form(user, {
        name: 'My Form',
        structure: {
          fields: [
            { label: 'Name', field_type: 'text', required: true, position: 1 },
            { label: 'Email', field_type: 'email', required: false, position: 2 }
          ]
        }
      })
    end

    it 'duplicates the form with a new name' do
      new_form = FormService.duplicate_form(user, form)

      expect(new_form).to be_persisted
      expect(new_form.name).to eq('My Form (1)')
      expect(new_form.form_fields.count).to eq(2)
      
      fields = new_form.form_fields.order(:position)
      expect(fields[0].label).to eq('Name')
      expect(fields[0].field_type).to eq('text')
      expect(fields[0].required).to be true
      
      expect(fields[1].label).to eq('Email')
      expect(fields[1].field_type).to eq('email')
      expect(fields[1].required).to be false
    end

    it 'increments the counter if duplicates already exist' do
      FormService.duplicate_form(user, form) # Creates "My Form (1)"
      new_form2 = FormService.duplicate_form(user, form) # Should create "My Form (2)"

      expect(new_form2.name).to eq('My Form (2)')
    end

    it 'strips existing counter from the base name' do
      new_form = FormService.duplicate_form(user, form) # "My Form (1)"
      new_form2 = FormService.duplicate_form(user, new_form) # Should create "My Form (2)"

      expect(new_form2.name).to eq('My Form (2)')
    end

    it 'raises an error if the form belongs to another user' do
      other_user = User.create!(email: 'other@example.com', password: 'securepassword123')
      
      expect {
        FormService.duplicate_form(other_user, form)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
