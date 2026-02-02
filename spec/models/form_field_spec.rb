require 'rails_helper'

RSpec.describe FormField, type: :model do
  it 'is a valid ActiveRecord model' do
    expect(defined?(FormField)).to be_truthy
    expect(FormField.ancestors).to include(ActiveRecord::Base)
  end

  it 'belongs to form' do
    expect(FormField.reflect_on_association(:form)).not_to be_nil
  end
end
