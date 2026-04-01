require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Crm::Hubspot::OAuth do
  let(:oauth) { described_class.new }
  let(:client_id) { 'fake_client_id' }
  let(:client_secret) { 'fake_client_secret' }
  let(:redirect_uri) { 'https://example.com/callback' }
  let(:scopes) { 'contacts companies' }

  before do
    # Stub HubspotConfig methods so specs are self-contained and independent of credentials
    allow(HubspotConfig).to receive(:authorize_url).and_return('https://app.hubspot.com/oauth/authorize')
    allow(HubspotConfig).to receive(:client_id).and_return(client_id)
    allow(HubspotConfig).to receive(:client_secret).and_return(client_secret)
    allow(HubspotConfig).to receive(:redirect_uri).and_return(redirect_uri)
    allow(HubspotConfig).to receive(:scopes).and_return(scopes)
  end

  describe '#authorize_url' do
    it 'returns the correct authorization URL' do
      state = 'random_state'
      url = oauth.authorize_url(state: state)
      
      uri = URI(url)
      expect(uri.host).to eq('app.hubspot.com')
      expect(uri.path).to eq('/oauth/authorize')
      
      params = Rack::Utils.parse_query(uri.query)
      expect(params['client_id']).to eq(client_id)
      expect(params['redirect_uri']).to eq(redirect_uri)
      expect(params['scope']).to eq(scopes)
      expect(params['state']).to eq(state)
    end
  end

  describe '#exchange_code' do
    let(:code) { 'auth_code' }
    let(:success_response) do
      {
        'access_token' => 'access_token_123',
        'refresh_token' => 'refresh_token_456',
        'expires_in' => 1800
      }.to_json
    end

    it 'returns parsed token response on success' do
      stub_request(:post, "https://api.hubapi.com/oauth/v1/token")
        .with(
          body: {
            "client_id" => client_id,
            "client_secret" => client_secret,
            "code" => code,
            "grant_type" => "authorization_code",
            "redirect_uri" => redirect_uri
          },
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        )
        .to_return(status: 200, body: success_response, headers: { 'Content-Type' => 'application/json' })

      result = oauth.exchange_code(code)

      expect(result[:access_token]).to eq('access_token_123')
      expect(result[:refresh_token]).to eq('refresh_token_456')
      expect(result[:expires_in]).to eq(1800)
    end

    it 'raises OAuthError on failure' do
      stub_request(:post, "https://api.hubapi.com/oauth/v1/token")
        .to_return(status: 400, body: { 'message' => 'Invalid code' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect { oauth.exchange_code(code) }.to raise_error(Crm::Hubspot::OAuthError, /HubSpot OAuth failed: Invalid code/)
    end
  end

  describe '#refresh_token' do
    let(:refresh_token_val) { 'refresh_token_789' }
    let(:success_response) do
      {
        'access_token' => 'new_access_token',
        'refresh_token' => 'new_refresh_token',
        'expires_in' => 1800
      }.to_json
    end

    it 'returns parsed token response on success' do
      stub_request(:post, "https://api.hubapi.com/oauth/v1/token")
        .with(
          body: {
            "client_id" => client_id,
            "client_secret" => client_secret,
            "refresh_token" => refresh_token_val,
            "grant_type" => "refresh_token",
            "redirect_uri" => redirect_uri
          },
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        )
        .to_return(status: 200, body: success_response, headers: { 'Content-Type' => 'application/json' })

      result = oauth.refresh_token(refresh_token_val)

      expect(result[:access_token]).to eq('new_access_token')
      expect(result[:refresh_token]).to eq('new_refresh_token')
      expect(result[:expires_in]).to eq(1800)
    end

    it 'raises OAuthError on failure' do
      stub_request(:post, "https://api.hubapi.com/oauth/v1/token")
        .to_return(status: 401, body: { 'message' => 'Invalid refresh token' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect { oauth.refresh_token(refresh_token_val) }.to raise_error(Crm::Hubspot::OAuthError, /HubSpot OAuth failed: Invalid refresh token/)
    end
  end
end
