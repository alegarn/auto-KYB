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
end
