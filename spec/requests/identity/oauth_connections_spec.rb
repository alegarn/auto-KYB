# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Identity::OauthConnections", type: :request do
  # ─────────────────────────────────────────────────────────────
  # DELETE /identity/oauth_connection
  # ─────────────────────────────────────────────────────────────
  describe "DELETE /identity/oauth_connection" do
    context "when unauthenticated" do
      it "redirects to sign_in" do
        delete identity_oauth_connection_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when authenticated but no Google account is connected" do
      let!(:user)           { create(:user, :subscribed, provider: nil, uid: nil) }
      let!(:session_record) { user.sessions.create! }

      before { cookies.signed[:session_token] = session_record.id }

      it "redirects to settings with an alert" do
        delete identity_oauth_connection_path
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to be_present
      end

      it "does not change the user" do
        expect { delete identity_oauth_connection_path }
          .not_to change { user.reload.provider }
      end
    end

    context "when authenticated and Google account is connected" do
      let!(:user)           { create(:user, :subscribed, provider: "google_oauth2", uid: "goog-uid") }
      let!(:session_record) { user.sessions.create! }

      before { cookies.signed[:session_token] = session_record.id }

      it "clears provider and uid" do
        delete identity_oauth_connection_path
        user.reload
        expect(user.provider).to be_nil
        expect(user.uid).to be_nil
      end

      it "redirects to settings with a notice" do
        delete identity_oauth_connection_path
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to be_present
      end
    end
  end
end
