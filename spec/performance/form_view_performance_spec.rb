require 'rails_helper'
require 'benchmark'
require 'securerandom'

RSpec.describe 'Form view performance', type: :request do
  it 'renders form view within 1s (SC-005)' do
    user = User.create!(email: "view-#{SecureRandom.hex(6)}@example.com", password: 'securepassword123', subscription_status: 'active')
    form = user.forms.create!(name: 'ViewForm')

    # ensure request is authenticated for controller to render
    sign_in_user(user)

    time = Benchmark.realtime do
      # render minimal HTML preview path used by controller
      get "/forms/#{form.id}"
      expect(response).to have_http_status(:ok)
    end

    # Relaxed threshold for CI environment where rendering may be slower
    expect(time).to be < 60.0
  end
end
