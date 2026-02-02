require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate

    def index
      render plain: "OK"
    end
  end

  describe "before_action :set_current_request_details" do
    context "setting Current.user_agent" do
      it "sets from HTTP_USER_AGENT env key" do
        @request.env["HTTP_USER_AGENT"] = "Mozilla/5.0"

        get :index

        expect(Current.user_agent).to eq("Mozilla/5.0")
      end
    end

    context "setting Current.ip_address" do
      it "sets from REMOTE_ADDR env key" do
        @request.env["REMOTE_ADDR"] = "192.168.1.1"

        get :index

        expect(Current.ip_address).to eq("192.168.1.1")
      end
    end
  end

  describe "before_action :authenticate" do
    controller do
      before_action :authenticate

      def index
        render plain: "OK"
      end
    end

    context "with valid session token" do
      it "sets Current.session from signed cookie" do
        user = User.create!(email: "test@example.com", password: "password123456")
        session = user.sessions.create!
        cookies.signed[:session_token] = session.id

        get :index

        expect(Current.session).to eq(session)
      end

      it "sets Current.session from unsigned cookie" do
        user = User.create!(email: "test@example.com", password: "password123456")
        session = user.sessions.create!
        cookies[:session_token] = session.id

        get :index

        expect(Current.session).to eq(session)
      end
    end

    context "without valid session token" do
      it "redirects to sign_in_path when no cookie exists" do
        cookies.delete(:session_token)

        get :index

        expect(response).to redirect_to(sign_in_path)
      end

      it "redirects to sign_in_path with invalid session id" do
        cookies.signed[:session_token] = "invalid-id"

        get :index

        expect(response).to redirect_to(sign_in_path)
      end

      it "redirects to sign_in_path with non-existent session id" do
        cookies.signed[:session_token] = 999_999

        get :index

        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
