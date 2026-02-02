require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    it "renders the Home/Index Inertia component" do
      get "/"
      expect(response.headers["X-Inertia"]).to eq("true")
      expect(response.parsed_body["component"]).to eq("Home/Index")
    end
  end
end
