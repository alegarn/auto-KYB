require 'rails_helper'

RSpec.describe CrmTokenRefreshJob, type: :job do
  describe '#perform' do
    let!(:active_connection) do
      create(:crm_connection, provider: 'hubspot', expires_at: 5.minutes.from_now)
    end
    let!(:active_not_expiring) do
      create(:crm_connection, provider: 'hubspot', expires_at: 1.hour.from_now)
    end
    let!(:inactive_connection) do
      create(:crm_connection, provider: 'hubspot', expires_at: 5.minutes.from_now, status: 'disconnected')
    end

    it 'refreshes token for active connections expiring soon' do
      service = double
      expect(Crm::ConnectionManager).to receive(:service_for).with(active_connection).and_return(service)
      expect(service).to receive(:refresh_token!)

      # Should not call for not expiring or inactive
      expect(Crm::ConnectionManager).not_to receive(:service_for).with(active_not_expiring)
      expect(Crm::ConnectionManager).not_to receive(:service_for).with(inactive_connection)

      described_class.perform_now
    end

    it 'logs and continues on error' do
      service = double
      allow(Crm::ConnectionManager).to receive(:service_for).with(active_connection).and_return(service)
      allow(service).to receive(:refresh_token!).and_raise(StandardError.new('Ouch!'))

      expect(Rails.logger).to receive(:error).with(/Token refresh failed for connection #{active_connection.id}/)
      
      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
