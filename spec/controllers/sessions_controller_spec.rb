require "rails_helper"

RSpec.describe SessionsController, type: :controller, inertia: true do
  let(:user) { User.create!(email: "test@example.com", password: "password123456") }
  let(:other_user) { User.create!(email: "other@example.com", password: "password123456") }

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

    context "when not authenticated" do
      it "redirects to sign in path" do
        get :index

        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "GET #new" do
    it "renders inertia with sessions/new component" do
      get :new

      expect(inertia.component).to eq("sessions/new")
    end
  end

  describe "POST #create" do
    context "with valid credentials" do
      it "creates a session" do
        expect {
          post :create, params: { email: user.email, password: "password123456" }
        }.to change { Session.count }.by(1)
      end

      it "sets the permanent session token cookie" do
        post :create, params: { email: user.email, password: "password123456" }

        expect(cookies.signed[:session_token]).to be_present
      end

      it "redirects to auth_loading_path" do
        post :create, params: { email: user.email, password: "password123456" }

        expect(response).to redirect_to(auth_loading_path)
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

      it "handles nil email parameter" do
        expect {
          post :create, params: { email: nil, password: "wrongpassword" }
        }.not_to change { Session.count }

        expect(response).to redirect_to(sign_in_path(email_hint: nil))
        expect(flash[:alert]).to eq("That email or password is incorrect")
      end
    end
  end

  describe "GET #omniauth" do
    let(:provider) { "google_oauth2" }
    let(:uid) { "google-uid-123" }
    let(:email) { "oauth@example.com" }

    def omniauth_hash(provider: provider, uid: uid, email: email)
      {
        "provider" => provider,
        "uid" => uid,
        "info" => {
          "email" => email
        }
      }
    end

    it "signs in an existing oauth user" do
      oauth_user = User.create!(
        email: email,
        provider: provider,
        uid: uid,
        password: "password123456"
      )
      request.env["omniauth.auth"] = omniauth_hash

      expect {
        get :omniauth, params: { provider: provider }
      }.to change { Session.count }.by(1)

      expect(response).to redirect_to(auth_loading_path)
      expect(cookies.signed[:session_token]).to be_present
      expect(Session.last.user_id).to eq(oauth_user.id)
    end

    it "links provider and uid for existing email user" do
      email_user = User.create!(email: email, password: "password123456")
      request.env["omniauth.auth"] = omniauth_hash

      expect {
        get :omniauth, params: { provider: provider }
      }.to change { Session.count }.by(1)

      email_user.reload
      expect(email_user.provider).to eq(provider)
      expect(email_user.uid).to eq(uid)
      expect(response).to redirect_to(auth_loading_path)
    end

    it "creates a user when email is not registered" do
      request.env["omniauth.auth"] = omniauth_hash

      expect {
        get :omniauth, params: { provider: provider }
      }.to change { User.count }.by(1)
       .and change { Session.count }.by(1)

      created_user = User.find_by(email: email)
      expect(created_user).to be_present
      expect(created_user.provider).to eq(provider)
      expect(created_user.uid).to eq(uid)
      expect(response).to redirect_to(auth_loading_path)
    end

    it "does not relink to a different oauth identity for same email" do
      conflicted_user = User.create!(
        email: email,
        provider: "google_oauth2",
        uid: "other-uid",
        password: "password123456"
      )
      allow(controller).to receive(:oauth_auth).and_return(omniauth_hash(provider: "google_oauth2", uid: uid, email: email))

      expect {
        get :omniauth, params: { provider: provider }
      }.not_to change { Session.count }

      conflicted_user.reload
      expect(conflicted_user.uid).to eq("other-uid")
      expect(response).to redirect_to(sign_in_path)
      expect(flash[:alert]).to eq("We could not sign you in with Google")
    end

    it "redirects to sign in when auth payload is invalid" do
      allow(controller).to receive(:oauth_auth).and_return({ "provider" => provider, "uid" => uid, "info" => {} })

      expect {
        get :omniauth, params: { provider: provider }
      }.not_to change { User.count }

      expect(response).to redirect_to(sign_in_path)
      expect(flash[:alert]).to eq("We could not sign you in with Google")
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

      context "when trying to delete another user's session" do
        let(:other_session) { other_user.sessions.create! }

        it "does not destroy the other user's session" do
          expect {
            delete :destroy, params: { id: other_session.id }
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when not authenticated" do
      let(:session) { user.sessions.create! }

      it "redirects to sign in path" do
        delete :destroy, params: { id: session.id }

        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
