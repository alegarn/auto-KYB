require 'rails_helper'

RSpec.describe Crm::Hubspot::DataFetcher do
  let(:client) { instance_double("Crm::Hubspot::Client") }
  let(:contacts_api) { instance_double("Hubspot::Crm::Contacts::BasicApi") }
  let(:companies_api) { instance_double("Hubspot::Crm::Companies::BasicApi") }
  let(:contacts_search_api) { instance_double("Hubspot::Crm::Contacts::SearchApi") }
  let(:companies_search_api) { instance_double("Hubspot::Crm::Companies::SearchApi") }
  let(:fetcher) { described_class.new(client) }

  before do
    allow(client).to receive(:contacts_api).and_return(contacts_api)
    allow(client).to receive(:companies_api).and_return(companies_api)
    allow(client).to receive(:contacts_search_api).and_return(contacts_search_api)
    allow(client).to receive(:companies_search_api).and_return(companies_search_api)
  end

  describe '#fetch_contacts' do
    let(:hubspot_contact) do
      double("HubspotContact",
             id: "123",
             properties: {
               "email" => "test@example.com",
               "firstname" => "John",
               "lastname" => "Doe",
               "phone" => "555-1234",
               "company" => "ACME Corp",
               "address" => "123 Main St"
             })
    end
    let(:paging) { double("Paging", next_page: double("NextPage", after: "cursor123")) }
    let(:response) { double("Response", results: [ hubspot_contact ], paging: paging) }

    it 'fetches and maps contacts correctly' do
      expect(contacts_api).to receive(:get_page).with(
        limit: 10,
        properties: described_class::CONTACT_PROPERTIES
      ).and_return(response)

      result = fetcher.fetch_contacts(limit: 10)

      expect(result[:results].size).to eq(1)
      contact_data = result[:results].first
      expect(contact_data[:external_contact_id]).to eq("123")
      expect(contact_data[:email]).to eq("test@example.com")
      expect(contact_data[:name]).to eq("John Doe")
      expect(contact_data[:phone]).to eq("555-1234")
      expect(contact_data[:company_name]).to eq("ACME Corp")
      expect(contact_data[:address][:street]).to eq("123 Main St")

      expect(result[:paging][:next][:after]).to eq("cursor123")
    end

    it 'passes the after cursor' do
      expect(contacts_api).to receive(:get_page).with(
        limit: 100,
        properties: described_class::CONTACT_PROPERTIES,
        after: "abc"
      ).and_return(response)

      fetcher.fetch_contacts(after: "abc")
    end
  end

  describe '#fetch_companies' do
    let(:hubspot_company) do
      double("HubspotCompany",
             id: "456",
             properties: {
               "name" => "Tech Inc",
               "phone" => "555-9876",
               "address" => "456 Tech Blvd",
               "domain" => "techinc.com",
               "country" => "US",
               "registration_number" => "REG789"
             })
    end
    let(:paging) { nil }
    let(:response) { double("Response", results: [ hubspot_company ], paging: paging) }

    it 'fetches and maps companies correctly' do
      expect(companies_api).to receive(:get_page).with(
        limit: 50,
        properties: described_class::COMPANY_PROPERTIES
      ).and_return(response)

      result = fetcher.fetch_companies(limit: 50)

      expect(result[:results].size).to eq(1)
      company_data = result[:results].first
      expect(company_data[:hubspot_id]).to eq("456")
      expect(company_data[:company_name]).to eq("Tech Inc")
      expect(company_data[:domain]).to eq("techinc.com")
      expect(company_data[:country]).to eq("US")
      expect(company_data[:company_id]).to eq("REG789")

      expect(result[:paging]).to be_nil
    end
  end

  describe '#search_contact_by_email' do
    let(:hubspot_contact) do
      double("HubspotContact",
             id: "789",
             properties: { "email" => "search@example.com", "firstname" => "Search", "lastname" => nil })
    end

    it 'returns mapped contact when found' do
      response = double("Response", results: [ hubspot_contact ])
      expect(contacts_search_api).to receive(:do_search).with(
        body: {
          filterGroups: [ {
            filters: [ {
              propertyName: "email",
              operator: "EQ",
              value: "search@example.com"
            } ]
          } ],
          properties: described_class::CONTACT_PROPERTIES,
          limit: 1
        }
      ).and_return(response)

      result = fetcher.search_contact_by_email("search@example.com")
      expect(result[:external_contact_id]).to eq("789")
      expect(result[:email]).to eq("search@example.com")
      expect(result[:name]).to eq("Search")
    end

    it 'returns nil when not found' do
      response = double("Response", results: [])
      expect(contacts_search_api).to receive(:do_search).and_return(response)

      result = fetcher.search_contact_by_email("notfound@example.com")
      expect(result).to be_nil
    end
  end

  describe '#search_companies' do
    let(:hubspot_company) do
      double("HubspotCompany",
             id: "101",
             properties: { "name" => "Acme Corp" })
    end

    it 'calls do_search with correct params and returns mapped result' do
      response = double("Response", results: [ hubspot_company ])
      expect(companies_search_api).to receive(:do_search).with(
        body: {
          query: 'Acme',
          properties: described_class::COMPANY_PROPERTIES,
          limit: 10
        }
      ).and_return(response)

      results = fetcher.search_companies('Acme')
      company = results.first
      expect(company[:hubspot_id]).to eq("101")
      expect(company[:company_name]).to eq("Acme Corp")
    end
  end
end
