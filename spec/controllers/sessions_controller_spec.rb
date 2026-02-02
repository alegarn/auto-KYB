require "rails_helper"

RSpec.describe SessionsController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password123456") }

  describe "GET #index" do
    context "when authenticated" do
      before do
        session = user.sessions.create!
        cookies.signed[:session_token] = session.id
      end

      it "assigns @sessions" do
        get :index

        expect(assigns(:sessions)).to eq(user.sessions.order(created_at: :desc))
      end
    end
  end

  describe "GET #new" do
    it "renders the new template" do
      get :new

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST #create" do
    context "with valid credentials" do
      it "creates a session" do
        expect {
          post :create, params: { email: user.email, password: "password123456" }
        }.to change { Session.count }.by(1)
      end

      it "sets the session token cookie" do
        post :create, params: { email: user.email, password: "password123456" }

        expect(cookies.signed[:session_token]).to be_present
      end

      it "redirects to dashboard_path" do
        post :create, params: { email: user.email, password: "password123456" }

        expect(response).to redirect_to(dashboard_path)
      end

      it "sets a success notice" do
        post :create, params: { email: user.email, password: "password123456" }

        expect(flash[:notice]).to eq("Signed in successfully")
      end
    end

    context "with invalid credentials" do
      it "does not create a session" do
        expect {
          post :create, params: { email: user.email, password: "wrongpassword" }
        }.not_to change { Session.count }
      end

      it "does not set the session token cookie" do
        post :create, params: { email: user.email, password: "wrongpassword" }

        expect(cookies.signed[:session_token]).to be_nil
      end

      it "redirects to sign_in_path with email hint" do
        post :create, params: { email: user.email, password: "wrongpassword" }

        expect(response).to redirect_to(sign_in_path(email_hint: user.email))
      end

      it "sets an error alert" do
        post :create, params: { email: user.email, password: "wrongpassword" }

        expect(flash[:alert]).to eq("That email or password is incorrect")
      end
    end
  end

  describe "DELETE #destroy" do
    context "when authenticated" do
      let(:session) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session.id
      end

      it "destroys the session" do
        expect {
          delete :destroy, params: { id: session.id }
        }.to change { Session.count }.by(-1)
      end

      it "redirects to sessions_path" do
        delete :destroy, params: { id: session.id }

        expect(response).to redirect_to(sessions_path)
      end

      it "sets a success notice" do
        delete :destroy, params: { id: session.id }

        expect(flash[:notice]).to eq("That session has been logged out")
      end
    end
  end
end
