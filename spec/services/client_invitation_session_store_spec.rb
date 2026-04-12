require "rails_helper"

RSpec.describe ClientInvitationSessionStore do
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:session) { {} }
  let(:store) { described_class.new(session) }
  let(:client_form_id) { SecureRandom.uuid }

  describe "#store" do
    it "stores password and metadata with decision_pending: true" do
      store.store(client_form_id: client_form_id, password: "abc123")

      entry = session[:client_form_one_time_passwords][client_form_id.to_s]
      expect(entry["password"]).to eq("abc123")
      expect(entry["decision_pending"]).to be true
      expect(entry["expires_at"]).to be_present
    end
  end

  describe "#fetch_live" do
    it "returns the entry when not expired" do
      store.store(client_form_id: client_form_id, password: "abc123")
      expect(store.fetch_live(client_form_id)).to be_present
    end

    it "returns nil when expired" do
      store.store(client_form_id: client_form_id, password: "abc123", expires_in: 1.second)
      travel 2.seconds
      expect(store.fetch_live(client_form_id)).to be_nil
    end

    it "returns nil when no entry exists" do
      expect(store.fetch_live("nonexistent")).to be_nil
    end
  end

  describe "#decision_pending?" do
    it "returns true when decision is pending" do
      store.store(client_form_id: client_form_id, password: "abc123")
      expect(store.decision_pending?(client_form_id)).to be true
    end

    it "returns false after decision is completed" do
      store.store(client_form_id: client_form_id, password: "abc123")
      store.complete_decision(client_form_id)
      expect(store.decision_pending?(client_form_id)).to be false
    end

    it "returns false when entry does not exist" do
      expect(store.decision_pending?("nonexistent")).to be false
    end
  end

  describe "#complete_decision" do
    it "marks decision as no longer pending" do
      store.store(client_form_id: client_form_id, password: "abc123")
      store.complete_decision(client_form_id)

      entry = session[:client_form_one_time_passwords][client_form_id.to_s]
      expect(entry["decision_pending"]).to be false
    end
  end

  describe "#consume_password" do
    it "returns the password and removes the entry" do
      store.store(client_form_id: client_form_id, password: "abc123")
      result = store.consume_password(client_form_id)
      expect(result).to eq("abc123")
      expect(session[:client_form_one_time_passwords][client_form_id.to_s]).to be_nil
    end

    it "returns nil when expired and removes the entry" do
      store.store(client_form_id: client_form_id, password: "abc123", expires_in: 1.second)
      travel 2.seconds
      expect(store.consume_password(client_form_id)).to be_nil
    end

    it "returns nil when no entry exists" do
      expect(store.consume_password("nonexistent")).to be_nil
    end
  end

  describe "#live_password" do
    it "returns the password without consuming it" do
      store.store(client_form_id: client_form_id, password: "abc123")
      expect(store.live_password(client_form_id)).to eq("abc123")
      # Entry should still exist
      expect(store.live_password(client_form_id)).to eq("abc123")
    end

    it "returns nil when expired" do
      store.store(client_form_id: client_form_id, password: "abc123", expires_in: 1.second)
      travel 2.seconds
      expect(store.live_password(client_form_id)).to be_nil
    end
  end
end
