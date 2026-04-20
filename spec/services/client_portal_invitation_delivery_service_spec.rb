require "rails_helper"

RSpec.describe ClientPortalInvitationDeliveryService do
  let(:user) { FactoryBot.create(:user, subscription_status: "active") }
  let(:client) { FactoryBot.create(:client, user: user, email: "client@example.com", name: "Jane Doe") }
  let(:form) { FactoryBot.create(:form, user: user, name: "KYB Form") }
  let(:client_form) { FactoryBot.create(:client_form, client: client, form: form) }
  let(:password) { "SecurePass123" }

  describe ".call" do
    it "sends the email and records delivery metadata" do
      expect {
        result = described_class.call(client_form: client_form, password: password, user: user)
        expect(result).to be_success
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      client_form.reload
      expect(client_form.invitation_emailed_at).to be_present
      expect(client_form.invitation_emailed_to).to eq("client@example.com")

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "client@example.com" ])
      expect(mail.subject).to include("Quick KYB")
    end

    it "returns failure when client has no email" do
      client.update!(email: nil)

      result = described_class.call(client_form: client_form, password: password, user: user)
      expect(result).not_to be_success
      expect(result.error).to include("email")
    end

    it "returns failure when password is blank" do
      result = described_class.call(client_form: client_form, password: nil, user: user)
      expect(result).not_to be_success
      expect(result.error.downcase).to include("password")
    end

    it "uses custom templates from user settings" do
      user.create_client_invitation_email_setting!(
        subject_template: "Access for {{client_name}}",
        body_template: "Hi {{client_name}}, your link: {{invite_link}} and password: {{password}}"
      )

      result = described_class.call(client_form: client_form, password: password, user: user)
      expect(result).to be_success

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Access for Jane Doe")
    end

    it "does not persist delivery metadata when mailer fails" do
      allow(ClientPortalInvitationMailer).to receive_message_chain(:with, :portal_access, :deliver_now).and_raise(Net::OpenTimeout)

      result = described_class.call(client_form: client_form, password: password, user: user)
      expect(result).not_to be_success

      client_form.reload
      expect(client_form.invitation_emailed_at).to be_nil
    end
  end
end
