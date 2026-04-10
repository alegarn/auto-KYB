require 'rails_helper'

RSpec.describe Crm::Hubspot::Client do
  let(:user) { create(:user) }
  let(:connection) do
    create(
      :crm_connection,
      provider: "hubspot",
      user: user,
      access_token: "old_access",
      refresh_token: "old_refresh",
      expires_at: expires_at,
      status: "active"
    )
  end
  let(:expires_at) { 1.hour.from_now }

  let(:hubspot_sdk) { double('Hubspot::Client') }
  let(:oauth_service) { instance_double(Crm::Hubspot::OAuth) }

  before do
    allow(::Hubspot::Client).to receive(:new).and_return(hubspot_sdk)
    allow(Crm::Hubspot::OAuth).to receive(:new).and_return(oauth_service)
  end

  describe '#initialize' do
    context 'when token is valid and not expiring soon' do
      let(:expires_at) { 1.day.from_now }

      it 'does not attempt to refresh the token' do
        expect(oauth_service).not_to receive(:refresh_token)
        described_class.new(connection)
      end
    end

    context 'when token is expiring soon' do
      let(:expires_at) { 2.minutes.from_now }
      let(:new_tokens) do
        {
          access_token: "new_access",
          refresh_token: "new_refresh",
          expires_in: 1800
        }
      end

      before do
        allow(oauth_service).to receive(:refresh_token).with("old_refresh").and_return(new_tokens)
      end

      it 'refreshes the token and updates the connection' do
        client = described_class.new(connection)

        connection.reload
        expect(connection.access_token).to eq("new_access")
        expect(connection.refresh_token).to eq("new_refresh")
        expect(connection.expires_at).to be_within(5.seconds).of(Time.current + 1800.seconds)
      end

      it 'uses the new access_token for the SDK' do
        described_class.new(connection)
        expect(::Hubspot::Client).to receive(:new).with(access_token: "new_access").and_return(hubspot_sdk)
        client = described_class.new(connection)
        client.sdk
      end
    end
  end

  describe 'API convenience methods' do
    let(:client) { described_class.new(connection) }
    let(:crm_double) { double('Crm') }
    let(:contacts_double) { double('Contacts') }
    let(:companies_double) { double('Companies') }

    before do
      allow(hubspot_sdk).to receive(:crm).and_return(crm_double)
      allow(crm_double).to receive(:contacts).and_return(contacts_double)
      allow(crm_double).to receive(:companies).and_return(companies_double)
    end

    describe '#contacts_api' do
      it 'delegates to sdk.crm.contacts.basic_api' do
        expect(contacts_double).to receive(:basic_api).and_return(:basic_api_result)
        expect(client.contacts_api).to eq(:basic_api_result)
      end
    end

    describe '#companies_api' do
      it 'delegates to sdk.crm.companies.basic_api' do
        expect(companies_double).to receive(:basic_api).and_return(:basic_api_result)
        expect(client.companies_api).to eq(:basic_api_result)
      end
    end

    describe '#contacts_search_api' do
      it 'delegates to sdk.crm.contacts.search_api' do
        expect(contacts_double).to receive(:search_api).and_return(:search_api_result)
        expect(client.contacts_search_api).to eq(:search_api_result)
      end
    end

    describe '#companies_search_api' do
      it 'delegates to sdk.crm.companies.search_api' do
        expect(companies_double).to receive(:search_api).and_return(:search_api_result)
        expect(client.companies_search_api).to eq(:search_api_result)
      end
    end

    describe '#api_request' do
      it 'delegates to sdk.api_request' do
        options = { method: "GET", path: "/test" }
        expect(hubspot_sdk).to receive(:api_request).with(options).and_return(:api_response)
        expect(client.api_request(options)).to eq(:api_response)
      end
    end
  end

  describe '#with_rate_limit_retry' do
    let(:client) { described_class.new(connection) }

    it 'yields normally if no error' do
      expect(client.with_rate_limit_retry { "success" }).to eq("success")
    end

    it 'retries when Hubspot::ApiError 429 is raised' do
      error = StandardError.new("Too Many Requests")
      stub_const("Hubspot::ApiError", Class.new(StandardError) do
        attr_accessor :code, :response_headers
        def initialize(code:, response_headers: {})
          @code = code
          @response_headers = response_headers
          super()
        end
      end)

      api_error = Hubspot::ApiError.new(code: 429, response_headers: { "Retry-After" => "1" })
      call_count = 0

      allow(client).to receive(:sleep)

      result = client.with_rate_limit_retry do
        call_count += 1
        raise api_error if call_count == 1
        "success after retry"
      end

      expect(result).to eq("success after retry")
      expect(call_count).to eq(2)
      expect(client).to have_received(:sleep).with(1)
    end

    it 'raises if other Hubspot::ApiError is raised' do
      stub_const("Hubspot::ApiError", Class.new(StandardError) do
        attr_accessor :code, :response_headers
        def initialize(code:, response_headers: {})
          @code = code
          @response_headers = response_headers
          super()
        end
      end)

      api_error = Hubspot::ApiError.new(code: 500)
      expect { client.with_rate_limit_retry { raise api_error } }.to raise_error(Hubspot::ApiError)
    end

    it 'gives up after max_retries' do
      stub_const("Hubspot::ApiError", Class.new(StandardError) do
        attr_accessor :code, :response_headers
        def initialize(code:, response_headers: {})
          @code = code
          @response_headers = response_headers
          super()
        end
      end)

      api_error = Hubspot::ApiError.new(code: 429, response_headers: { "Retry-After" => "1" })
      allow(client).to receive(:sleep)

      expect {
        client.with_rate_limit_retry(max_retries: 2) { raise api_error }
      }.to raise_error(Hubspot::ApiError)

      expect(client).to have_received(:sleep).twice
    end
  end
end
