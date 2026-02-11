require 'rails_helper'

RSpec.describe "Countries", type: :request do
  describe "GET /countries" do
    context "when unauthenticated" do
      it "is not accessible (redirects to sign_in)" do
        get '/countries', as: :json
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when authenticated" do
      it "returns the countries JSON" do
        user = sign_in_user
        get '/countries', headers: { 'Cookie' => "session_token=#{Current.session.id}" }, as: :json
        expect(response).to have_http_status(:ok)
        payload = JSON.parse(response.body)
        expect(payload).to be_an(Array)
        # sanity check: Norway exists and has code and flag
        norway = payload.find { |c| c['name'] == 'Norway' }
        expect(norway).to be_present
        expect(norway['code']).to eq('NO')
        expect(norway['flag']).to be_present
      end
    end
  end
end
