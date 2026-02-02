require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate

    def index
      render plain: "OK"
    end
  end

  describe "before_action :set_current_request_details" do
    it "sets Current.user_agent" do
      @request.env["HTTP_USER_AGENT"] = "Mozilla/5.0"

      get :index

      expect(Current.user_agent).to eq("Mozilla/5.0")
    end

    it "sets Current.ip_address" do
      @request.env["REMOTE_ADDR"] = "192.168.1.1"

      get :index

      expect(Current.ip_address).to eq("192.168.1.1")
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
      it "sets Current.session" do
        user = User.create!(email: "test@example.com", password: "password123456")
        session = user.sessions.create!
        cookies.signed[:session_token] = session.id

        get :index

        expect(Current.session).to eq(session)
      end
    end

    context "without valid session token" do
      it "redirects to sign_in_path" do
        cookies.delete(:session_token)

        get :index

        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
