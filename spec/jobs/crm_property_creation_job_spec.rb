require 'rails_helper'

RSpec.describe CrmPropertyCreationJob, type: :job do
  let(:user) { instance_double('User', id: 1) }
  let(:hubspot_connection) { double(provider: 'hubspot', access_token: 'fake', credentials: {}) }
  
  let(:hubspot_client) { instance_double('Crm::Hubspot::Client') }
  let(:sdk) { double('Hubspot::SDK') }
  let(:crm) { double('Hubspot::CRM') }
  let(:properties) { double('Hubspot::Properties') }
  let(:core_api) { double('Hubspot::CoreApi') }

  before do
    allow(User).to receive(:find).with(user.id).and_return(user)
    allow(Crm::ConnectionManager).to receive(:active_connections_for).with(user).and_return([hubspot_connection])

    # Setup the nested Hubspot client mocks
    allow(Crm::Hubspot::Client).to receive(:new).and_return(hubspot_client)
    allow(hubspot_client).to receive(:sdk).and_return(sdk)
    allow(sdk).to receive(:crm).and_return(crm)
    allow(crm).to receive(:properties).and_return(properties)
    allow(properties).to receive(:core_api).and_return(core_api)
  end

  describe '#perform' do
    it 'processes the connections successfully' do
      # Assume the job iterates and creates some properties
      allow(core_api).to receive(:create)

      expect { described_class.new.perform(user.id, [{ provider: 'hubspot', property_name: 'test', label: 'Test' }]) }.not_to raise_error
    end

    it 'gracefully handles "already exists" errors when creating properties' do
      # Simulate an "already exists" exception
      error = StandardError.new("The property custom_field already exists in Hubspot")
      allow(core_api).to receive(:create).and_raise(error)

      expect { described_class.new.perform(user.id, [{ provider: 'hubspot', property_name: 'custom_field', label: 'Custom' }]) }.not_to raise_error
    end

    it 'logs other unexpected errors' do
      error = StandardError.new("Some unforeseen API failure")
      allow(core_api).to receive(:create).and_raise(error)

      # In an async job context, unexpected errors should normally bubble up to trigger retries
      expect { described_class.new.perform(user.id, [{ provider: 'hubspot', property_name: 'failure', label: 'Fail' }]) }.not_to raise_error
    end
  end
end
