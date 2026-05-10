# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleOAuthConfig do
  describe ".redirect_uri" do
    let(:credentials) do
      {
        app: {
          base_url: "https://auto-kyb-production.up.railway.app"
        }
      }
    end

    it "prefers APP_BASE_URL when present" do
      env = { "APP_BASE_URL" => "https://preview.quick-kyb.example" }

      expect(described_class.redirect_uri(
        credentials: credentials,
        env: env,
        rails_env: ActiveSupport::StringInquirer.new("development")
      )).to eq("https://preview.quick-kyb.example/auth/google_oauth2/callback")
    end

    it "falls back to localhost in development when APP_BASE_URL is missing" do
      expect(described_class.redirect_uri(
        credentials: credentials,
        env: {},
        rails_env: ActiveSupport::StringInquirer.new("development")
      )).to eq("http://localhost:3100/auth/google_oauth2/callback")
    end

    it "uses the configured app base url in production when APP_BASE_URL is missing" do
      expect(described_class.redirect_uri(
        credentials: credentials,
        env: {},
        rails_env: ActiveSupport::StringInquirer.new("production")
      )).to eq("https://auto-kyb-production.up.railway.app/auth/google_oauth2/callback")
    end
  end
end
