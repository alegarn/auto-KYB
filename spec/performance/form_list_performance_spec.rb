require 'benchmark'

RSpec.describe 'Form list performance' do
  it 'returns forms list within 2s (SC-001)' do
    user = User.create!(email: 'perf@example.com', password: 'password')
    # create a moderate number of forms to emulate load
    1000.times do |i|
      user.forms.create!(name: "Form #{i}")
    end

    time = Benchmark.realtime do
      user.forms.order(created_at: :desc).to_a
    end

    expect(time).to be < 2.0
  end
end
