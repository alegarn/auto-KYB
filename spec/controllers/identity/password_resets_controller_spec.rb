require "rails_helper"

RSpec.describe Identity::PasswordResetsController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password123456", verified: true) }
  let(:unverified_user) { User.create!(email: "unverified@example.com", password: "password123456", verified: false) }

  describe "GET #new" do
    it "renders the new template" do
      get :new

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST #create" do
    context "with valid email for verified user" do
      it "assigns @user" do
        post :create, params: { email: user.email }

        expect(assigns(:user)).to eq(user)
      end

      it "sends password reset email" do
        expect {
          post :create, params: { email: user.email }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob).at_least(:once)
      end

      it "redirects to sign_in_path with notice" do
        post :create, params: { email: user.email }

        expect(response).to redirect_to(sign_in_path)
        expect(flash[:notice]).to eq("Check your email for reset instructions")
      end
    end

    context "with email for unverified user" do
      it "does not assign @user" do
        post :create, params: { email: unverified_user.email }

        expect(assigns(:user)).to be_nil
      end

      it "does not send password reset email" do
        expect {
          post :create, params: { email: unverified_user.email }
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "redirects to new_identity_password_reset_path with alert" do
        post :create, params: { email: unverified_user.email }

        expect(response).to redirect_to(new_identity_password_reset_path)
        expect(flash[:alert]).to eq("You can't reset your password until you verify your email")
      end
    end

    context "with non-existent email" do
      it "does not assign @user" do
        post :create, params: { email: "nonexistent@example.com" }

        expect(assigns(:user)).to be_nil
      end

      it "does not send password reset email" do
        expect {
          post :create, params: { email: "nonexistent@example.com" }
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "redirects to new_identity_password_reset_path with alert" do
        post :create, params: { email: "nonexistent@example.com" }

        expect(response).to redirect_to(new_identity_password_reset_path)
        expect(flash[:alert]).to eq("You can't reset your password until you verify your email")
      end
    end
  end

  describe "GET #edit" do
    context "with valid password reset token" do
      it "assigns @user" do
        token = user.generate_token_for(:password_reset)

        get :edit, params: { sid: token }

        expect(assigns(:user)).to eq(user)
      end
    end

    context "with invalid password reset token" do
      it "redirects to new_identity_password_reset_path with alert" do
        get :edit, params: { sid: "invalid_token" }

        expect(response).to redirect_to(new_identity_password_reset_path)
        expect(flash[:alert]).to eq("That password reset link is invalid")
      end
    end
  end

  describe "PATCH #update" do
    context "with valid password reset token and valid params" do
      let(:valid_params) do
        {
          password: "newpassword123456",
          password_confirmation: "newpassword123456"
        }
      end

      it "updates the user password" do
        token = user.generate_token_for(:password_reset)

        patch :update, params: { sid: token }.merge(valid_params)

        expect(user.reload.authenticate("newpassword123456")).to eq(user)
      end

      it "redirects to sign_in_path with notice" do
        token = user.generate_token_for(:password_reset)

        patch :update, params: { sid: token }.merge(valid_params)

        expect(response).to redirect_to(sign_in_path)
        expect(flash[:notice]).to eq("Your password was reset successfully. Please sign in")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          password: "short",
          password_confirmation: "short"
        }
      end

      it "does not update the user password" do
        token = user.generate_token_for(:password_reset)

        expect {
          patch :update, params: { sid: token }.merge(invalid_params)
        }.not_to change { user.reload.password_digest }
      end

      it "renders edit with unprocessable_entity status" do
        token = user.generate_token_for(:password_reset)

        patch :update, params: { sid: token }.merge(invalid_params)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid password reset token" do
      let(:valid_params) do
        {
          password: "newpassword123456",
          password_confirmation: "newpassword123456"
        }
      end

      it "redirects to new_identity_password_reset_path with alert" do
        patch :update, params: { sid: "invalid_token" }.merge(valid_params)

        expect(response).to redirect_to(new_identity_password_reset_path)
        expect(flash[:alert]).to eq("That password reset link is invalid")
      end
    end
  end
end
