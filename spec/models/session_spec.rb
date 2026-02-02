require "rails_helper"

RSpec.describe Session, type: :model do
  describe "associations" do
    it "belongs to a user" do
      user = User.create!(email: "test@example.com", password: "password123456")
      session = user.sessions.create!

      expect(session.user).to eq(user)
    end

    it "requires a user" do
      session = Session.new

      expect(session).to be_invalid
      expect(session.errors[:user]).to include("must exist")
    end
  end

  describe "callbacks" do
    around do |example|
      original_user_agent = Current.user_agent
      original_ip_address = Current.ip_address

      example.run

      Current.user_agent = original_user_agent
      Current.ip_address = original_ip_address
    end

    context "when Current values are set" do
      it "sets user_agent from Current on create" do
        user = User.create!(email: "test@example.com", password: "password123456")
        Current.user_agent = "Mozilla/5.0"

        session = user.sessions.create!

        expect(session.user_agent).to eq("Mozilla/5.0")
      end

      it "sets ip_address from Current on create" do
        user = User.create!(email: "test@example.com", password: "password123456")
        Current.ip_address = "192.168.1.1"

        session = user.sessions.create!

        expect(session.ip_address).to eq("192.168.1.1")
      end
    end

    context "when Current values are nil" do
      it "sets user_agent to nil when Current.user_agent is nil" do
        user = User.create!(email: "test@example.com", password: "password123456")
        Current.user_agent = nil

        session = user.sessions.create!

        expect(session.user_agent).to be_nil
      end

      it "sets ip_address to nil when Current.ip_address is nil" do
        user = User.create!(email: "test@example.com", password: "password123456")
        Current.ip_address = nil

        session = user.sessions.create!

        expect(session.ip_address).to be_nil
      end
    end
  end
end
