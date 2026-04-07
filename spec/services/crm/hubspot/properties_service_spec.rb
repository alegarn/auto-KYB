require 'rails_helper'

RSpec.describe Crm::Hubspot::PropertiesService do
  let(:user) { instance_double('User', id: 1) }
  let(:connection) { double(provider: 'hubspot', access_token: 'fake', id: 1) }
  let(:hubspot_client) { instance_double('Crm::Hubspot::Client') }
  let(:sdk) { double('Hubspot::SDK', crm: double(properties: double(core_api: double(:get_all => double(results: []))))) }

  before do
    allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([ connection ])
    allow(Crm::Hubspot::Client).to receive(:new).and_return(hubspot_client)
    allow(hubspot_client).to receive(:sdk).and_return(sdk)
  end

  describe '#list_properties' do
    let(:prop1) { double('Prop', name: 'email', label: 'Email', type: 'string', field_type: 'text', options: [], calculated: false, modification_metadata: double(read_only_value: false)) }
    let(:prop2) { double('Prop', name: 'calculated_field', label: 'Math', type: 'number', field_type: 'number', options: [], calculated: true, modification_metadata: double(read_only_value: false)) }
    let(:prop3) { double('Prop', name: 'read_only_field', label: 'System', type: 'string', field_type: 'text', options: [], calculated: false, modification_metadata: double(read_only_value: true)) }

    before do
      allow(sdk.crm.properties.core_api).to receive(:get_all).and_return(double(results: [ prop1, prop2, prop3 ]))
      # Clear cache for testing
      Rails.cache.clear
    end

    it 'filters out calculated and read-only properties' do
      service = described_class.new(user)
      results = service.list_properties

      expect(results.count).to eq(1)
      expect(results.first[:name]).to eq('email')
    end

    it 'returns an empty array if no properties found' do
      allow(sdk.crm.properties.core_api).to receive(:get_all).and_return(double(results: []))
      service = described_class.new(user)
      expect(service.list_properties).to eq([])
    end
  end
end
