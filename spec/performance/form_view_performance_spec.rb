require 'benchmark'

RSpec.describe 'Form view performance' do
  it 'renders form view within 1s (SC-005)' do
    user = User.create!(email: 'view@example.com', password: 'password')
    form = user.forms.create!(name: 'ViewForm')

    time = Benchmark.realtime do
      # render minimal HTML preview path used by controller
      get "/forms/#{form.id}"
      expect(response).to have_http_status(:ok)
    end

    expect(time).to be < 1.0
  end
end
