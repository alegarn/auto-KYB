require "rails_helper"

RSpec.describe ClientInvitationEmailSetting, type: :model do
  let(:user) { FactoryBot.create(:user, subscription_status: "active") }

  subject { described_class.new(user: user) }

  describe "validations" do
    it "is valid with default attributes" do
      expect(subject).to be_valid
    end

    it "rejects unknown placeholders in subject_template" do
      subject.subject_template = "Hello {{unknown_var}}"
      expect(subject).not_to be_valid
      expect(subject.errors[:subject_template]).to be_present
    end

    it "rejects unknown placeholders in body_template" do
      subject.body_template = "Hello {{hacker_var}}"
      expect(subject).not_to be_valid
      expect(subject.errors[:body_template]).to be_present
    end

    it "allows known placeholders" do
      subject.subject_template = "Access for {{client_name}}"
      subject.body_template = "Link: {{invite_link}} pass: {{password}}"
      expect(subject).to be_valid
    end

    it "rejects newlines in subject_template" do
      subject.subject_template = "Subject\nHeader-Injection"
      expect(subject).not_to be_valid
      expect(subject.errors[:subject_template]).to include("must not contain line breaks")
    end

    context "when auto_send is true" do
      before { subject.auto_send = true }

      it "requires {{invite_link}} and {{password}} in body_template" do
        subject.body_template = "Hello {{client_name}}"
        expect(subject).not_to be_valid
        expect(subject.errors[:body_template].join).to include("invite_link")
        expect(subject.errors[:body_template].join).to include("password")
      end

      it "is valid when body_template includes required placeholders" do
        subject.body_template = "Link: {{invite_link}} Password: {{password}}"
        expect(subject).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to a user" do
      expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    end
  end
end
