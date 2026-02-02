require 'rails_helper'

RSpec.describe FormService do
  it 'is defined' do
    expect(defined?(FormService)).to be_truthy
  end

  it 'responds to initialize_default_for_user' do
    expect(FormService).to respond_to(:initialize_default_for_user)
  end
end
