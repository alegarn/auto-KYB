require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "POST /sign_in" do
    let(:user) { create(:user, password: "password123456") }

    it "creates a session and redirects to auth loading" do
      expect {
        post sign_in_path, params: { email: user.email, password: "password123456" }
      }.to change(Session, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(auth_loading_path)
      expect(response.cookies["session_token"]).to be_present
      expect(flash[:notice]).to eq("Signed in successfully")
    end

    it "does not create a session with invalid credentials" do
      expect {
        post sign_in_path, params: { email: user.email, password: "wrong-password" }
      }.not_to change(Session, :count)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(sign_in_path(email_hint: user.email))
      expect(response.cookies["session_token"]).to be_nil
      expect(flash[:alert]).to eq("That email or password is incorrect")
    end
  end
end
