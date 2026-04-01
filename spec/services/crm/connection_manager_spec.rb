require 'rails_helper'

RSpec.describe Crm::ConnectionManager do
  describe '.service_for' do
    it 'returns HubspotService for hubspot provider' do
      conn = build_stubbed(:crm_connection, provider: 'hubspot')
      service = described_class.service_for(conn)
      expect(service).to be_a(Crm::HubspotService)
    end

    it 'returns SalesforceService for salesforce provider' do
      conn = build_stubbed(:crm_connection, provider: 'salesforce')
      service = described_class.service_for(conn)
      expect(service).to be_a(Crm::SalesforceService)
    end

    it 'returns ZohoService for zoho provider' do
      conn = build_stubbed(:crm_connection, provider: 'zoho')
      service = described_class.service_for(conn)
      expect(service).to be_a(Crm::ZohoService)
    end

    it 'raises ArgumentError for unknown provider' do
      conn = build_stubbed(:crm_connection, provider: 'unknown_provider')
      expect { described_class.service_for(conn) }.to raise_error(ArgumentError)
    end
  end

  describe '.active_connections_for' do
    it 'returns only active connections for a user' do
      user = create(:user)
      active = create(:crm_connection, user: user, status: 'active')
      inactive = create(:crm_connection, user: user, status: 'inactive', provider: 'salesforce')

      results = described_class.active_connections_for(user)
      expect(results).to include(active)
      expect(results).not_to include(inactive)
    end
  end
end
