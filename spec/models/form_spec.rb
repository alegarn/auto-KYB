require 'rails_helper'

RSpec.describe Form, type: :model do
  it 'is a valid ActiveRecord model' do
    expect(defined?(Form)).to be_truthy
    expect(Form.ancestors).to include(ActiveRecord::Base)
  end

  it 'has expected associations' do
    expect(Form.reflect_on_association(:form_fields)).not_to be_nil
    expect(Form.reflect_on_association(:user)).not_to be_nil
  end

  context 'validations' do
    it 'validates presence of name' do
      form = Form.new
      expect(form.valid?).to be false
      expect(form.errors[:name]).not_to be_empty
    end

    it 'allows duplicate names for the same user (no uniqueness constraint)' do
      user = FactoryBot.create(:user)
      FactoryBot.create(:form, user: user, name: 'Duplicate')
      f2 = FactoryBot.build(:form, user: user, name: 'Duplicate')
      expect(f2.valid?).to be true
    end
  end
end
