require "rails_helper"

RSpec.describe ClientPortalInvitationMailer, type: :mailer do
  describe "#portal_access" do
    let(:mail) do
      described_class.with(
        recipient_email: "client@example.com",
        client_name: "Jane Doe",
        form_name: "KYB Form",
        invite_link: "https://example.com/portal/login/abc123",
        password: "OneTimePass42",
        rendered_subject: "Your Quick KYB secure form access",
        rendered_body: "Hello Jane Doe, your link: https://example.com/portal/login/abc123 password: OneTimePass42"
      ).portal_access
    end

    it "sends to the correct recipient" do
      expect(mail.to).to eq([ "client@example.com" ])
    end

    it "uses the rendered subject" do
      expect(mail.subject).to eq("Your Quick KYB secure form access")
    end

    it "includes the rendered body in the HTML part" do
      expect(mail.html_part.body.to_s).to include("Hello Jane Doe")
      expect(mail.html_part.body.to_s).to include("https://example.com/portal/login/abc123")
      expect(mail.html_part.body.to_s).to include("OneTimePass42")
    end

    it "includes the rendered body in the text part" do
      expect(mail.text_part.body.to_s).to include("Hello Jane Doe")
      expect(mail.text_part.body.to_s).to include("OneTimePass42")
    end

    it "is a multipart email with both text and HTML" do
      expect(mail.parts.size).to eq(2)
      content_types = mail.parts.map(&:content_type)
      expect(content_types).to include(a_string_matching(/text\/html/))
      expect(content_types).to include(a_string_matching(/text\/plain/))
    end
  end
end
