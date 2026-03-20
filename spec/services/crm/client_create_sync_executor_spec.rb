require 'rails_helper'

RSpec.describe Crm::ClientCreateSyncExecutor, type: :service do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user, name: 'John', email: 'john@example.com', company_name: 'Acme Corp') }
  let(:connection) { create(:crm_connection, user: user, provider: 'hubspot', status: 'active') }
  let(:service) { double('CrmService') }
  let(:request_context) { { 'sync_address_to_contact' => 'true' } }

  subject do
    described_class.new(
      client: client,
      connection: connection,
      service: service,
      request_context: request_context
    )
  end

  it 'reuses CrmClientLink.external_contact_id on retry instead of calling create_contact again' do
    create(:crm_client_link, client: client, crm_connection: connection,
           external_contact_id: 'existing_ct_1', external_company_id: nil)

    allow(service).to receive(:search_companies).and_return([])
    allow(service).to receive(:create_company).and_return({ id: 'comp_new' })
    allow(service).to receive(:associate_contact_to_company)

    expect(service).not_to receive(:create_contact)

    result = subject.call

    expect(result[:external_contact_id]).to eq('existing_ct_1')
  end

  it 'searches by email before create_contact when no external_contact_id is stored' do
    allow(service).to receive(:search_contact_by_email).with(client.email).and_return(nil)
    allow(service).to receive(:create_contact).and_return({ id: 'ct_created', action: :created })
    allow(service).to receive(:search_companies).and_return([])
    allow(service).to receive(:create_company).and_return({ id: 'comp_1' })
    allow(service).to receive(:associate_contact_to_company)

    expect(service).to receive(:search_contact_by_email).with(client.email).ordered
    expect(service).to receive(:create_contact).ordered

    result = subject.call

    expect(result[:external_contact_id]).to eq('ct_created')
  end

  it 'persists a found contact id from provider search and skips contact creation' do
    allow(service).to receive(:search_contact_by_email).with(client.email).and_return({ id: 'ct_found', email: client.email })
    allow(service).to receive(:search_companies).and_return([])
    allow(service).to receive(:create_company).and_return({ id: 'comp_1' })
    allow(service).to receive(:associate_contact_to_company)

    expect(service).not_to receive(:create_contact)

    result = subject.call

    expect(result[:external_contact_id]).to eq('ct_found')

    link = CrmClientLink.find_by!(client: client, crm_connection: connection)
    expect(link.external_contact_id).to eq('ct_found')
  end

  it 'reuses an existing external_company_id instead of calling create_company' do
    create(:crm_client_link, client: client, crm_connection: connection,
           external_contact_id: 'ct_1', external_company_id: 'comp_existing')

    allow(service).to receive(:associate_contact_to_company)

    expect(service).not_to receive(:create_contact)
    expect(service).not_to receive(:search_companies)
    expect(service).not_to receive(:create_company)

    result = subject.call

    expect(result[:external_company_id]).to eq('comp_existing')
  end

  it 'treats an already-existing contact-company association as success' do
    create(:crm_client_link, client: client, crm_connection: connection,
           external_contact_id: 'ct_1', external_company_id: 'comp_1')

    allow(service).to receive(:associate_contact_to_company)
      .with('ct_1', 'comp_1')
      .and_return(true)

    result = subject.call

    expect(result[:external_contact_id]).to eq('ct_1')
    expect(result[:external_company_id]).to eq('comp_1')
  end

  it 'does not create a duplicate CRM contact when a previous attempt created the contact and failed later' do
    # Simulate: first attempt created the contact but failed during association
    create(:crm_client_link, client: client, crm_connection: connection,
           external_contact_id: 'ct_from_attempt_1', external_company_id: nil)

    request_ctx = { 'sync_address_to_contact' => 'true', 'external_company_id' => 'comp_given' }
    executor = described_class.new(
      client: client, connection: connection, service: service, request_context: request_ctx
    )

    allow(service).to receive(:associate_contact_to_company)

    expect(service).not_to receive(:create_contact)
    expect(service).not_to receive(:search_contact_by_email)

    result = executor.call

    expect(result[:external_contact_id]).to eq('ct_from_attempt_1')
    expect(result[:external_company_id]).to eq('comp_given')
  end
end
