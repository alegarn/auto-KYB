require "rails_helper"

RSpec.describe "Settings - Client Invitation Email", type: :request do
  let(:user) { sign_in_user }

  describe "PATCH /settings/client_invitation_email" do
    it "creates the setting when it does not exist" do
      user # trigger sign_in

      patch settings_client_invitation_email_path, params: {
        client_invitation_email_setting: {
          auto_send: false,
          subject_template: "Access for {{client_name}}",
          body_template: "Hello {{client_name}}, link: {{invite_link}}, pass: {{password}}"
        }
      }

      expect(response).to redirect_to(settings_path)

      setting = user.reload.client_invitation_email_setting
      expect(setting).to be_present
      expect(setting.subject_template).to eq("Access for {{client_name}}")
    end

    it "updates an existing setting" do
      user.create_client_invitation_email_setting!(auto_send: false)

      patch settings_client_invitation_email_path, params: {
        client_invitation_email_setting: {
          auto_send: true,
          body_template: "Link: {{invite_link}} Pass: {{password}}"
        }
      }

      expect(response).to redirect_to(settings_path)
      expect(user.client_invitation_email_setting.reload.auto_send).to be true
    end

    it "rejects unknown placeholders with 422" do
      user # trigger sign_in

      patch settings_client_invitation_email_path, params: {
        client_invitation_email_setting: {
          body_template: "Hello {{evil_var}}"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects auto_send without required placeholders" do
      user # trigger sign_in

      patch settings_client_invitation_email_path, params: {
        client_invitation_email_setting: {
          auto_send: true,
          body_template: "Hello {{client_name}}"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
