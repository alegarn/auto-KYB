require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  describe "GET /index" do
    it "returns http success" do
      user = User.create!(email: "test@example.com", password: "password123456")
      session = user.sessions.create!
      
      # Set signed cookie for authentication
      get "/dashboard", headers: { "Cookie" => "session_token=#{session.id}; path=/; httponly" }
      expect(response).to have_http_status(:success)
    end
  end

end
