require "rails_helper"

RSpec.describe ClientPortalInvitationTemplateRenderer do
  let(:variables) do
    {
      "client_name" => "Jane Doe",
      "client_email" => "jane@example.com",
      "form_name" => "KYB Onboarding",
      "invite_link" => "https://example.com/portal/abc123",
      "password" => "Secret42"
    }
  end

  describe ".render" do
    it "interpolates default templates when no custom templates are provided" do
      result = described_class.render(variables: variables)
      expect(result).to be_success
      expect(result.subject).to eq("Your Quick KYB secure form access")
      expect(result.body).to include("Jane Doe")
      expect(result.body).to include("https://example.com/portal/abc123")
      expect(result.body).to include("Secret42")
    end

    it "interpolates custom subject and body templates" do
      result = described_class.render(
        subject_template: "Portal access for {{client_name}}",
        body_template: "Hello {{client_name}}, your link is {{invite_link}}",
        variables: variables
      )
      expect(result).to be_success
      expect(result.subject).to eq("Portal access for Jane Doe")
      expect(result.body).to eq("Hello Jane Doe, your link is https://example.com/portal/abc123")
    end

    it "rejects unknown placeholders" do
      result = described_class.render(
        body_template: "Hello {{unknown_var}}",
        variables: variables
      )
      expect(result).not_to be_success
      expect(result.errors.first).to include("unknown_var")
    end

    it "strips newlines from the subject to prevent header injection" do
      result = described_class.render(
        subject_template: "Subject\r\nBcc: attacker@evil.com",
        variables: variables
      )
      expect(result).to be_success
      expect(result.subject).not_to include("\n")
      expect(result.subject).not_to include("\r")
    end

    it "leaves unknown variables as-is when they are not in the variable hash" do
      result = described_class.render(
        body_template: "Link: {{invite_link}}",
        variables: { "invite_link" => "http://example.com" }
      )
      expect(result).to be_success
      expect(result.body).to eq("Link: http://example.com")
    end
  end
end
