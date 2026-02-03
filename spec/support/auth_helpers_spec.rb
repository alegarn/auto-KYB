require 'rails_helper'

RSpec.describe 'Auth helpers' do
  it 'provides a helper to sign in users in tests' do
    expect(defined?(sign_in_user)).to be_truthy
  end
end
