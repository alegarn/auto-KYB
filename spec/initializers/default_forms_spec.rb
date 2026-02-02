require 'rails_helper'

RSpec.describe 'Default forms initializer' do
  it 'FormInitializer.DEFAULT_KYB is defined with expected keys' do
    expect(defined?(FormInitializer::DEFAULT_KYB)).to be_truthy
    expect(FormInitializer::DEFAULT_KYB[:name]).to eq('Default KYB Form')
    expect(FormInitializer::DEFAULT_KYB[:fields]).to be_an(Array)
    expect(FormInitializer::DEFAULT_KYB[:fields].length).to be >= 1
  end
end
