require 'rails_helper'

RSpec.describe Crm::Hubspot::PropertiesService do
  let(:user) { instance_double('User', id: 1) }
  let(:connection) { double(provider: 'hubspot', access_token: 'fake', id: 1) }
  let(:hubspot_client) { instance_double('Crm::Hubspot::Client') }
  let(:sdk) { double('Hubspot::SDK', crm: double(properties: double(core_api: double(:get_all => double(results: []))))) }

  before do
    allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([connection])
    allow(Crm::Hubspot::Client).to receive(:new).and_return(hubspot_client)
    allow(hubspot_client).to receive(:sdk).and_return(sdk)
  end

  describe '#list_properties' do
    it 'returns an empty array if no properties found' do
      service = described_class.new(user)
      expect(service.list_properties).to eq([])
    end
  end
end

