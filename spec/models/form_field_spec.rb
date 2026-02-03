require 'rails_helper'

RSpec.describe FormField, type: :model do
  it 'is a valid ActiveRecord model' do
    expect(defined?(FormField)).to be_truthy
    expect(FormField.ancestors).to include(ActiveRecord::Base)
  end

  it 'belongs to form' do
    expect(FormField.reflect_on_association(:form)).not_to be_nil
  end

  context 'validations' do
    it 'validates presence of label and field_type' do
      ff = FormField.new
      expect(ff.valid?).to be false
      expect(ff.errors[:label]).not_to be_empty
      expect(ff.errors[:field_type]).not_to be_empty
    end

    it 'validates field_type inclusion' do
      invalid = FormField.new(label: 'X', field_type: 'unsupported')
      expect(invalid.valid?).to be false
      expect(invalid.errors[:field_type]).not_to be_empty
    end
  end
end
