require 'rails_helper'

RSpec.describe FormInitializer do
  it 'is defined' do
    expect(defined?(FormInitializer)).to be_truthy
  end

  it 'responds to default_for_user' do
    expect(FormInitializer).to respond_to(:default_for_user)
  end
end
