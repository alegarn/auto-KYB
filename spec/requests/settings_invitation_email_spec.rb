require "rails_helper"

RSpec.describe "Settings - Client Invitation Email", type: :request do
  let(:user) { sign_in_user }

  describe "PATCH /settings/client_invitation_email" do
    it "creates the setting when it does not exist" do
      user # trigger sign_in

      patch settings_client_invitation_email_path, params: {
        client_invitation_email_setting: {
          subject_template: "Access for {{client_name}}",
          body_template: "Hello {{client_name}}, link: {{invite_link}}, pass: {{password}}"
        }
      }

      expect(response).to redirect_to(settings_path)

      setting = user.reload.client_invitation_email_setting
      expect(setting).to be_present
      expect(setting.subject_template).to eq("Access for {{client_name}}")
    end

    it "updates template fields only (auto_send is ignored)" do
      user.create_client_invitation_email_setting!(auto_send: false)

      patch settings_client_invitation_email_path, params: {
        client_invitation_email_setting: {
          subject_template: "New subject",
          body_template: "Updated body"
        }
      }

      expect(response).to redirect_to(settings_path)
      setting = user.client_invitation_email_setting.reload
      expect(setting.subject_template).to eq("New subject")
      expect(setting.auto_send).to be false # auto_send unchanged
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

    it "rejects body_template missing required placeholders when auto_send is already on" do
      user.create_client_invitation_email_setting!(
        auto_send: true,
        body_template: "Link: {{invite_link}} Pass: {{password}}"
      )

      patch settings_client_invitation_email_path, params: {
        client_invitation_email_setting: {
          body_template: "Hello {{client_name}}"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /settings/client_invitation_email/auto_send" do
    it "enables auto_send with no template set" do
      user # trigger sign_in

      patch settings_invite_auto_send_path, params: {
        client_invitation_email_setting: { auto_send: true }
      }

      expect(response).to redirect_to(settings_path)
      expect(user.reload.client_invitation_email_setting.auto_send).to be true
    end

    it "disables auto_send" do
      user.create_client_invitation_email_setting!(auto_send: true)

      patch settings_invite_auto_send_path, params: {
        client_invitation_email_setting: { auto_send: false }
      }

      expect(response).to redirect_to(settings_path)
      expect(user.client_invitation_email_setting.reload.auto_send).to be false
    end

    it "does not change template fields" do
      user.create_client_invitation_email_setting!(
        auto_send: false,
        subject_template: "My subject",
        body_template: "My body"
      )

      patch settings_invite_auto_send_path, params: {
        client_invitation_email_setting: { auto_send: true }
      }

      setting = user.client_invitation_email_setting.reload
      expect(setting.auto_send).to be true
      expect(setting.subject_template).to eq("My subject")
      expect(setting.body_template).to eq("My body")
    end
  end
end
