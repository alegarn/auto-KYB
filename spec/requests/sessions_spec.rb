# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  # ─────────────────────────────────────────────────────────────
  # GET /sign_in
  # ─────────────────────────────────────────────────────────────
  describe "GET /sign_in" do
    it "renders the sign-in page (200)" do
      get sign_in_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # POST /sign_in  (magic-link dispatch — no password auth)
  # ─────────────────────────────────────────────────────────────
  describe "POST /sign_in" do
    context "with a verified user" do
      let!(:verified_user) { create(:user, :verified, :subscribed) }

      it "enqueues the passwordless mail" do
        expect {
          post sign_in_path, params: { email: verified_user.email }
        }.to have_enqueued_mail(UserMailer, :passwordless).with(params: { user: verified_user }, args: [])
      end

      it "redirects to sign_in with a notice" do
        post sign_in_path, params: { email: verified_user.email }
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:notice]).to be_present
      end

      it "does not create a session directly" do
        expect {
          post sign_in_path, params: { email: verified_user.email }
        }.not_to change(Session, :count)
      end
    end

    context "with an unverified user" do
      let!(:unverified_user) { create(:user, verified: false, subscription_status: "active") }

      it "enqueues the email_verification mail" do
        expect {
          post sign_in_path, params: { email: unverified_user.email }
        }.to have_enqueued_mail(UserMailer, :email_verification).with(params: { user: unverified_user }, args: [])
      end

      it "redirects to sign_in with the same opaque notice (anti-enumeration)" do
        post sign_in_path, params: { email: unverified_user.email }
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "when email does not match any user" do
      it "does not enqueue any mail" do
        expect {
          post sign_in_path, params: { email: "ghost@example.com" }
        }.not_to have_enqueued_mail
      end

      it "still redirects with the same notice (no enumeration)" do
        post sign_in_path, params: { email: "ghost@example.com" }
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:notice]).to be_present
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /sign_in/:sid  (Passwordless magic link click)
  # ─────────────────────────────────────────────────────────────
  describe "GET /sign_in/:sid" do
    let(:user) { create(:user, :subscribed, onboarding_completed: true) }

    context "with a valid signin token" do
      it "creates a session and redirects to auth_loading" do
        token = user.generate_token_for(:signin)

        expect {
          get passwordless_sign_in_path(sid: token)
        }.to change(Session, :count).by(1)

        expect(response).to redirect_to(auth_loading_path)
        expect(flash[:notice]).to be_present
      end

      it "sets a signed session cookie in the response" do
        token = user.generate_token_for(:signin)
        get passwordless_sign_in_path(sid: token)

        expect(response.cookies["session_token"]).to be_present
      end
    end

    context "with an invalid token" do
      it "redirects to sign_in with an alert" do
        get passwordless_sign_in_path(sid: "bogus-signed-token")
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to be_present
      end

      it "does not create a session" do
        expect {
          get passwordless_sign_in_path(sid: "bogus")
        }.not_to change(Session, :count)
      end
    end

    context "when user is canceled beyond the 1-year retention window" do
      let(:user) { create(:user, :canceled_over_a_year_ago, verified: true) }

      it "does not create a session" do
        token = user.generate_token_for(:signin)
        expect {
          get passwordless_sign_in_path(sid: token)
        }.not_to change(Session, :count)
      end

      it "redirects to sign_in with an alert" do
        token = user.generate_token_for(:signin)
        get passwordless_sign_in_path(sid: token)
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /auth/:provider/callback  (OmniAuth)
  # ─────────────────────────────────────────────────────────────
  describe "GET /auth/:provider/callback" do
    let(:provider) { "google_oauth2" }
    let(:uid)      { "goog-uid-001" }
    let(:email)    { "oauth@example.com" }

    context "existing oauth user (provider + uid match)" do
      let!(:oauth_user) { create(:user, :subscribed, email: email, provider: provider, uid: uid, onboarding_completed: true) }

      before { mock_omniauth(provider, uid: uid, email: email) }

      it "creates a session" do
        expect {
          get "/auth/#{provider}/callback"
        }.to change(Session, :count).by(1)
      end

      it "redirects to auth_loading with a notice" do
        get "/auth/#{provider}/callback"
        expect(response).to redirect_to(auth_loading_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "user exists by email but has no provider linked yet" do
      let!(:email_user) { create(:user, :subscribed, email: email, provider: nil, uid: nil, onboarding_completed: true) }

      before { mock_omniauth(provider, uid: uid, email: email) }

      it "links the provider/uid to the existing user" do
        get "/auth/#{provider}/callback"
        email_user.reload
        expect(email_user.provider).to eq(provider)
        expect(email_user.uid).to eq(uid)
      end

      it "creates a session and redirects to auth_loading" do
        expect {
          get "/auth/#{provider}/callback"
        }.to change(Session, :count).by(1)
        expect(response).to redirect_to(auth_loading_path)
      end
    end

    context "no matching user exists (brand-new OAuth signup)" do
      before { mock_omniauth(provider, uid: uid, email: email) }

      it "redirects to sign_in without creating a user" do
        expect {
          get "/auth/#{provider}/callback"
        }.not_to change(User, :count)

        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "user with same email already has a DIFFERENT provider/uid (conflict)" do
      let!(:conflicted_user) { create(:user, :subscribed, email: email, provider: provider, uid: "other-uid") }

      before { mock_omniauth(provider, uid: uid, email: email) }

      it "does not create a session" do
        expect {
          get "/auth/#{provider}/callback"
        }.not_to change(Session, :count)
      end

      it "does not change the conflicted user's uid" do
        get "/auth/#{provider}/callback"
        expect(conflicted_user.reload.uid).to eq("other-uid")
      end

      it "redirects to sign_in with an alert" do
        get "/auth/#{provider}/callback"
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "payload missing email" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
          'provider' => provider,
          'uid'      => uid,
          'info'     => {}
        )
      end

      it "redirects to sign_in with an alert" do
        get "/auth/#{provider}/callback"
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is already authenticated (linking a provider)" do
      let(:current_user)    { create(:user, :subscribed, provider: nil, uid: nil) }
      let!(:session_record) { current_user.sessions.create! }

      before do
        cookies.signed[:session_token] = session_record.id
        mock_omniauth(provider, uid: uid, email: email)
      end

      it "links the provider to the current user" do
        get "/auth/#{provider}/callback"
        current_user.reload
        expect(current_user.provider).to eq(provider)
        expect(current_user.uid).to eq(uid)
      end

      it "redirects to auth_loading with a notice" do
        get "/auth/#{provider}/callback"
        expect(response).to redirect_to(auth_loading_path)
        expect(flash[:notice]).to be_present
      end

      it "redirects with an alert when payload has no uid" do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
          'provider' => provider,
          'uid'      => nil,
          'info'     => { 'email' => email }
        )
        get "/auth/#{provider}/callback"
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to be_present
      end

      it "does not relink when oauth identity is already owned by another user" do
        owner = create(:user, :subscribed, provider: provider, uid: uid)

        get "/auth/#{provider}/callback"

        current_user.reload
        owner.reload

        expect(current_user.provider).to be_nil
        expect(current_user.uid).to be_nil
        expect(owner.provider).to eq(provider)
        expect(owner.uid).to eq(uid)
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq("This Google account is already linked to another user.")
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # DELETE /sessions/:id
  # ─────────────────────────────────────────────────────────────
  describe "DELETE /sessions/:id" do
    let(:user)              { create(:user, :subscribed) }
    let!(:own_session)      { user.sessions.create! }
    let(:other_user)        { create(:user, :subscribed) }
    let!(:other_session)    { other_user.sessions.create! }

    context "when authenticated" do
      before { cookies.signed[:session_token] = own_session.id }

      it "destroys the session" do
        expect {
          delete session_path(own_session)
        }.to change(Session, :count).by(-1)
      end

      it "redirects to sessions_path with a notice" do
        delete session_path(own_session)
        expect(response).to redirect_to(sessions_path)
        expect(flash[:notice]).to be_present
      end

      it "returns 404 when trying to delete another user's session" do
        # Rails converts ActiveRecord::RecordNotFound to 404 in request specs
        delete session_path(other_session)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign_in" do
        delete session_path(own_session)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
