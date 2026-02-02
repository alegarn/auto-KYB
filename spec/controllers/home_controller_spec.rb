require "rails_helper"

RSpec.describe HomeController, type: :controller, inertia: true do
  describe "GET #index" do
    it "renders inertia with Home component" do
      get :index

      expect(inertia.component).to eq("Home/Index")
    end

    it "does not require authentication" do
      get :index

      expect(response).to have_http_status(:ok)
    end
  end
end
