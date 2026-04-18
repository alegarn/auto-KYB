require 'rails_helper'
require 'webmock/rspec'

RSpec.describe GmailDelivery do
  describe '.delivery_credentials' do
    it 'prefers dedicated gmail_delivery credentials over legacy values' do
      credentials = build_credentials(
        gmail_delivery: {
          client_id: 'gmail-client-id',
          client_secret: 'gmail-client-secret',
          refresh_token: 'gmail-refresh-token'
        },
        google: {
          client_id: 'legacy-client-id',
          client_secret: 'legacy-client-secret',
          refresh_token: 'legacy-refresh-token'
        }
      )

      expect(described_class.delivery_credentials(credentials: credentials, env: {})).to eq(
        client_id: 'gmail-client-id',
        client_secret: 'gmail-client-secret',
        refresh_token: 'gmail-refresh-token'
      )
    end

    it 'allows dedicated GMAIL_* env vars to override dedicated credentials' do
      credentials = build_credentials(
        gmail_delivery: {
          client_id: 'gmail-client-id',
          client_secret: 'gmail-client-secret',
          refresh_token: 'gmail-refresh-token'
        }
      )

      env = {
        'GMAIL_CLIENT_ID' => 'env-client-id',
        'GMAIL_CLIENT_SECRET' => 'env-client-secret',
        'GMAIL_REFRESH_TOKEN' => 'env-refresh-token'
      }

      expect(described_class.delivery_credentials(credentials: credentials, env: env)).to eq(
        client_id: 'env-client-id',
        client_secret: 'env-client-secret',
        refresh_token: 'env-refresh-token'
      )
    end

    it 'falls back to legacy google credentials and env vars' do
      credentials = build_credentials(
        google: {
          client_id: 'legacy-client-id'
        }
      )

      env = {
        'GOOGLE_CLIENT_SECRET' => 'legacy-env-secret',
        'GOOGLE_REFRESH_TOKEN' => 'legacy-env-refresh-token'
      }

      expect(described_class.delivery_credentials(credentials: credentials, env: env)).to eq(
        client_id: 'legacy-client-id',
        client_secret: 'legacy-env-secret',
        refresh_token: 'legacy-env-refresh-token'
      )
    end

    it 'does not mix dedicated gmail_delivery values with legacy google values' do
      credentials = build_credentials(
        gmail_delivery: {
          client_id: 'gmail-client-id'
        },
        google: {
          client_secret: 'legacy-client-secret',
          refresh_token: 'legacy-refresh-token'
        }
      )

      expect(described_class.delivery_credentials(credentials: credentials, env: {})).to eq(
        client_id: 'gmail-client-id',
        client_secret: nil,
        refresh_token: nil
      )
    end
  end

  describe '.oauth_redirect_uri' do
    it 'allows GMAIL_OAUTH_REDIRECT_URI to override credential-based redirect settings' do
      credentials = build_credentials(
        gmail_delivery: {
          redirect_uri: 'https://mail.example.com/oauth/callback'
        }
      )

      env = {
        'GMAIL_OAUTH_REDIRECT_URI' => 'https://override.example.com/oauth/callback'
      }

      expect(described_class.oauth_redirect_uri(credentials: credentials, env: env)).to eq(
        'https://override.example.com/oauth/callback'
      )
    end

    it 'prefers a dedicated gmail_delivery redirect uri over app.base_url' do
      credentials = build_credentials(
        gmail_delivery: {
          redirect_uri: 'https://mail.example.com/oauth/callback'
        },
        app: {
          base_url: 'https://auto-kyb.example.com'
        }
      )

      expect(described_class.oauth_redirect_uri(credentials: credentials, env: {})).to eq(
        'https://mail.example.com/oauth/callback'
      )
    end

    it 'builds the callback from app.base_url when no dedicated redirect uri is set' do
      credentials = build_credentials(
        app: {
          base_url: 'https://auto-kyb.example.com'
        }
      )

      expect(described_class.oauth_redirect_uri(credentials: credentials, env: {})).to eq(
        'https://auto-kyb.example.com/auth/google_oauth2/callback'
      )
    end

    it 'rejects non-local redirect uris that do not use https' do
      credentials = build_credentials(
        gmail_delivery: {
          redirect_uri: 'http://mail.example.com/oauth/callback'
        }
      )

      expect do
        described_class.oauth_redirect_uri(credentials: credentials, env: {})
      end.to raise_error(ArgumentError, /must use HTTPS outside localhost/)
    end

    it 'raises outside local environments when no redirect source exists' do
      expect do
        described_class.oauth_redirect_uri(credentials: build_credentials({}), env: {}, rails_env: ActiveSupport::StringInquirer.new('production'))
      end.to raise_error(ArgumentError, /Missing redirect URI configuration/)
    end
  end

  describe '#deliver!' do
    let(:mail) do
      Mail.new do
        from 'sender@example.com'
        to 'recipient@example.com'
        subject 'Hello'
        body 'Test message'
      end
    end

    before do
      allow(described_class).to receive(:delivery_credentials).and_return(credentials_hash)

      stub_request(:post, 'https://oauth2.googleapis.com/token')
        .to_return(
          status: 200,
          body: { access_token: 'gmail-access-token' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
        .with(headers: { 'Authorization' => 'Bearer gmail-access-token' })
        .to_return(
          status: 200,
          body: { id: 'gmail-message-id' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    let(:credentials_hash) do
      {
        client_id: 'client-id',
        client_secret: 'client-secret',
        refresh_token: 'refresh-token'
      }
    end

    it 'sends the encoded message through the Gmail API and returns the mail object' do
      expected_cache_key = "gmail_api_access_token/client-id/#{Digest::SHA256.hexdigest(credentials_hash[:refresh_token])}"

      expect(Rails.cache).to receive(:fetch).with(expected_cache_key, expires_in: 50.minutes).and_yield

      expect(described_class.new.deliver!(mail)).to eq(mail)

      expect(WebMock).to have_requested(:post, 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
    end

    it 'surfaces non-JSON Gmail API failures without raising an internal parsing error' do
      allow(Rails.cache).to receive(:fetch).and_yield

      stub_request(:post, 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
        .with(headers: { 'Authorization' => 'Bearer gmail-access-token' })
        .to_return(status: 502, body: '<html>Bad Gateway</html>', headers: { 'Content-Type' => 'text/html' })

      expect do
        described_class.new.deliver!(mail)
      end.to raise_error(RuntimeError, /Bad Gateway/)
    end

    it 'invalidates the cached access token and retries once on Gmail auth failures' do
      expected_cache_key = "gmail_api_access_token/client-id/#{Digest::SHA256.hexdigest(credentials_hash[:refresh_token])}"

      expect(Rails.cache).to receive(:fetch).with(expected_cache_key, expires_in: 50.minutes).and_yield
      expect(Rails.cache).to receive(:delete).with(expected_cache_key)

      stub_request(:post, 'https://oauth2.googleapis.com/token')
        .to_return(
          {
            status: 200,
            body: { access_token: 'cached-access-token' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          },
          {
            status: 200,
            body: { access_token: 'fresh-access-token' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          }
        )

      stub_request(:post, 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
        .with(headers: { 'Authorization' => 'Bearer cached-access-token' })
        .to_return(
          status: 401,
          body: { error: { message: 'Invalid Credentials' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
        .with(headers: { 'Authorization' => 'Bearer fresh-access-token' })
        .to_return(
          status: 200,
          body: { id: 'gmail-message-id' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect(described_class.new.deliver!(mail)).to eq(mail)
    end
  end

  describe '#verify!' do
    let(:credentials_hash) do
      {
        client_id: 'client-id',
        client_secret: 'client-secret',
        refresh_token: 'refresh-token'
      }
    end

    before do
      allow(described_class).to receive(:delivery_credentials).and_return(credentials_hash)

      stub_request(:post, 'https://oauth2.googleapis.com/token')
        .to_return(
          status: 400,
          body: {
            error: 'invalid_grant',
            error_description: 'Token has been expired or revoked.'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'raises an actionable error when the refresh token is invalid' do
      expect(Rails.cache).not_to receive(:fetch)

      expect { described_class.new.verify! }.to raise_error(described_class::InvalidRefreshTokenError, described_class::INVALID_GRANT_MESSAGE)
    end
  end

  def build_credentials(data)
    Object.new.tap do |store|
      store.define_singleton_method(:dig) do |*keys|
        data.dig(*keys)
      end
    end
  end
end
