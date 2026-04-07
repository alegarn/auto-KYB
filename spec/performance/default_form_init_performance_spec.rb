require 'benchmark'
require 'securerandom'

RSpec.describe 'Default form init performance' do
  it 'initializes default form within 1s (SC-007)' do
    user = User.create!(email: "init-#{SecureRandom.hex(4)}@example.com", password: 'securepassword123', subscription_status: 'active')

    time = Benchmark.realtime do
      FormService.initialize_default_for_user(user)
    end

    expect(time).to be < 1.0
  end
end
