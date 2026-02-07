require 'rails_helper'
require 'ostruct'

RSpec.describe ClientPortal::SessionService, type: :service do
  let(:request) { ActionDispatch::TestRequest.create }
  let(:cookies) { request.cookie_jar }

  describe '.set_cookie and .current_client_form' do
    it 'sets a signed cookie and current_client_form returns the found ClientForm' do
      client_form = OpenStruct.new(access_token: 'token-123', expires_at: 2.days.from_now)

      found = double('ClientFormRecord')
      allow(ClientForm).to receive(:find_by).with(access_token: 'token-123').and_return(found)

      described_class.set_cookie(cookies, client_form)

      expect(cookies.signed[described_class::COOKIE_NAME]).to eq('token-123')

      result = described_class.current_client_form(cookies)
      expect(result).to eq(found)
    end

    it 'returns nil when no cookie present' do
      expect(cookies.signed[described_class::COOKIE_NAME]).to be_nil
      expect(described_class.current_client_form(cookies)).to be_nil
    end
  end

  describe '.clear_cookie' do
    it 'deletes the cookie' do
      client_form = OpenStruct.new(access_token: 'token-to-delete', expires_at: nil)
      described_class.set_cookie(cookies, client_form)
      expect(cookies.signed[described_class::COOKIE_NAME]).to eq('token-to-delete')

      described_class.clear_cookie(cookies)
      expect(cookies.signed[described_class::COOKIE_NAME]).to be_nil
    end
  end
end
