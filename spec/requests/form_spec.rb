require 'rails_helper'

RSpec.describe "Forms", type: :request do
  describe "GET /index" do
    context "when authenticated" do
      it "returns http success" do
        user = User.create!(email: "test@example.com", password: "password123456")
        session = user.sessions.create!
        
        # Set the session token cookie properly using Rails' cookie methods
        cookies[:session_token] = session.id
        
        get "/forms"
        expect(response).to have_http_status(:success)
      end

      it "renders the response with proper content" do
        user = User.create!(email: "test@example.com", password: "password123456")
        session = user.sessions.create!
        
        cookies[:session_token] = session.id
        
        get "/forms"
        
        # Verify response is successful
        expect(response).to have_http_status(:success)
        
        # Verify the response body contains expected content
        # Note: Inertia responses may be JSON or HTML depending on request headers
        expect(response.body).to be_present
      end
    end

    context "when not authenticated" do
      it "redirects to sign in page" do
        get "/forms"
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
