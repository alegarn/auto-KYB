require 'rails_helper'

RSpec.describe Crm::DataExporter, type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }

  before { clear_enqueued_jobs }

  it 'creates transfers and enqueues jobs for active connections only' do
    active = create(:crm_connection, user: user, status: 'active')
    _inactive = create(:crm_connection, user: user, status: 'inactive', provider: 'salesforce')

    exporter = described_class.new(client)

    expect {
      exporter.export_to_all_active!
    }.to change { CrmTransfer.count }.by(1)

    expect(enqueued_jobs.select { |j| j[:job] == CrmDataExportJob }).not_to be_empty
  end

  it 'creates a pending transfer record for each active connection' do
    create(:crm_connection, user: user, status: 'active')
    create(:crm_connection, user: user, status: 'active', provider: 'salesforce')

    exporter = described_class.new(client)

    expect {
      exporter.export_to_all_active!
    }.to change { CrmTransfer.where(status: 'pending').count }.by(2)
  end
end
