require "rails_helper"

RSpec.describe Identity::EmailsController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password123456") }

  before do
    session = user.sessions.create!
    cookies.signed[:session_token] = session.id
  end

  describe "GET #edit" do
    it "assigns @user" do
      get :edit

      expect(assigns(:user)).to eq(user)
    end
  end

  describe "PATCH #update" do
    context "with valid params and correct password challenge" do
      let(:valid_params) do
        {
          email: "new@example.com",
          password_challenge: "password123456"
        }
      end

      it "updates the user email" do
        patch :update, params: valid_params

        expect(user.reload.email).to eq("new@example.com")
      end

      it "sends email verification" do
        expect {
          patch :update, params: valid_params
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob).at_least(:once)
      end

      it "redirects to root_path with notice" do
        patch :update, params: valid_params

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Your email has been changed")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          email: "invalid-email",
          password_challenge: "password123456"
        }
      end

      it "does not update the user" do
        expect {
          patch :update, params: invalid_params
        }.not_to change { user.reload.email }
      end

      it "renders edit with unprocessable_content status" do
        patch :update, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with incorrect password challenge" do
      let(:wrong_password_params) do
        {
          email: "new@example.com",
          password_challenge: "wrongpassword"
        }
      end

      it "does not update the user" do
        expect {
          patch :update, params: wrong_password_params
        }.not_to change { user.reload.email }
      end

      it "renders edit with unprocessable_content status" do
        patch :update, params: wrong_password_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when email does not change" do
      let(:same_email_params) do
        {
          email: "test@example.com",
          password_challenge: "password123456"
        }
      end

      it "redirects to root_path without email verification notice" do
        patch :update, params: same_email_params

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to be_nil
      end

      it "does not send email verification" do
        expect {
          patch :update, params: same_email_params
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end
  end
end
