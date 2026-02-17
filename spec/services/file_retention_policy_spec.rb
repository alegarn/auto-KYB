require "rails_helper"

RSpec.describe FileRetentionPolicy do
  describe ".purge_delay_seconds" do
    context "when UPLOADED_FILE_PURGE_DELAY_SECONDS is set in ENV" do
      it "returns the ENV value as an integer" do
        original = ENV["UPLOADED_FILE_PURGE_DELAY_SECONDS"]
        ENV["UPLOADED_FILE_PURGE_DELAY_SECONDS"] = "123"

        expect(described_class.purge_delay_seconds).to eq 123
      ensure
        ENV["UPLOADED_FILE_PURGE_DELAY_SECONDS"] = original
      end
    end

    context "when UPLOADED_FILE_PURGE_DELAY_SECONDS is not set" do
      it "returns the default 1.day in seconds" do
        original = ENV.delete("UPLOADED_FILE_PURGE_DELAY_SECONDS")

        expect(described_class.purge_delay_seconds).to eq 1.day.to_i
      ensure
        ENV["UPLOADED_FILE_PURGE_DELAY_SECONDS"] = original if original
      end
    end
  end

  describe ".purge_delay" do
    it "returns an ActiveSupport::Duration based on purge_delay_seconds" do
      allow(described_class).to receive(:purge_delay_seconds).and_return(5)

      expect(described_class.purge_delay).to eq 5.seconds
    end
  end

  describe ".as_json" do
    it "exposes starts_on and purge_delay_seconds" do
      allow(described_class).to receive(:purge_delay_seconds).and_return(10)

      expect(described_class.as_json).to eq({
        starts_on: FileRetentionPolicy::STARTS_ON,
        purge_delay_seconds: 10
      })
    end
  end
end
