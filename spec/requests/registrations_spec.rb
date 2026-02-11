require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "POST /sign_up" do
    context "with nested registration and password" do
      let(:params) do
        { registration: { email: "user@example.com", password: "securepass123", password_confirmation: "securepass123" } }
      end

      it "creates a user and sets a session cookie" do
        expect {
          post "/sign_up", params: params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:redirect)
        expect(response.cookies['session_token']).to be_present
      end
    end

    context "with missing password" do
      let(:params) do
        { registration: { email: "bad@example.com", password: "" } }
      end

      it "does not create a user and returns 422" do
        expect {
          post "/sign_up", params: params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
