require "rails_helper"

RSpec.describe RegistrationsController, type: :controller, inertia: true do
  describe "GET #new" do
    it "renders inertia with Registrations/New component" do
      get :new

      expect(inertia.component).to eq("registrations/new")
    end

    it "passes user as prop" do
      get :new

      expect(inertia.props[:user]).to be_a_new(User)
    end
  end

  describe "POST #create" do
    context "with valid params" do
      let(:valid_params) do
        {
          email: "new@example.com",
          password: "password123456",
          password_confirmation: "password123456"
        }
      end

      it "creates a new user" do
        expect {
          post :create, params: valid_params
        }.to change { User.count }.by(1)
      end

      it "creates a session for the user" do
        expect {
          post :create, params: valid_params
        }.to change { Session.count }.by(1)
      end

      it "sets the session token cookie" do
        post :create, params: valid_params

        expect(cookies.signed[:session_token]).to be_present
      end

      it "does not enqueue email verification (email sending disabled)" do
        expect {
          post :create, params: valid_params
        }.not_to have_enqueued_mail(UserMailer, :email_verification)
      end

      it "redirects to dashboard_path" do
        post :create, params: valid_params

        expect(response).to redirect_to(dashboard_path)
      end

      it "sets a success notice" do
        post :create, params: valid_params

        expect(flash[:notice]).to eq("Welcome! You have signed up successfully")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          email: "invalid-email",
          password: "short",
          password_confirmation: "short"
        }
      end

      it "does not create a new user" do
        expect {
          post :create, params: invalid_params
        }.not_to change { User.count }
      end

      it "does not create a session" do
        expect {
          post :create, params: invalid_params
        }.not_to change { Session.count }
      end

      it "does not set the session token cookie" do
        post :create, params: invalid_params

        expect(cookies.signed[:session_token]).to be_nil
      end

      it "renders the new template with unprocessable_entity status" do
        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
