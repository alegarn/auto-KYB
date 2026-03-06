require "rails_helper"

RSpec.describe Crm::HubspotService do
  let(:connection) { create(:crm_connection, provider: "hubspot") }
  subject(:service) { described_class.new(connection) }

  let(:oauth_double) { instance_double(Crm::Hubspot::OAuth) }
  let(:client_double) { instance_double(Crm::Hubspot::Client) }

  before do
    allow(Crm::Hubspot::OAuth).to receive(:new).and_return(oauth_double)
    allow(Crm::Hubspot::Client).to receive(:new).and_return(client_double)
  end

  describe "#authorize_url" do
    it "delegates to OAuth object" do
      allow(oauth_double).to receive(:authorize_url).and_return("https://hubspot.com/oauth")

      expect(service.authorize_url).to eq("https://hubspot.com/oauth")
      expect(oauth_double).to have_received(:authorize_url).with(state: kind_of(String))
    end
  end

  describe "#exchange_token" do
    let(:tokens) do
      {
        access_token: "new_access",
        refresh_token: "new_refresh",
        expires_in: 3600
      }
    end

    it "exchanges code and updates the connection" do
      allow(oauth_double).to receive(:exchange_code).with("code123").and_return(tokens)

      service.exchange_token("code123")

      connection.reload
      expect(connection.access_token).to eq("new_access")
      expect(connection.refresh_token).to eq("new_refresh")
      expect(connection.status).to eq("active")
    end
  end

  describe "#refresh_token!" do
    let(:tokens) do
      {
        access_token: "refreshed_access",
        refresh_token: "refreshed_refresh",
        expires_in: 3600
      }
    end

    it "refreshes using OAuth and updates connection" do
      allow(oauth_double).to receive(:refresh_token).with(connection.refresh_token).and_return(tokens)

      service.refresh_token!

      connection.reload
      expect(connection.access_token).to eq("refreshed_access")
      expect(connection.refresh_token).to eq("refreshed_refresh")
    end
  end

  describe "#test_connection" do
    let(:api_response) { instance_double("Faraday::Response", body: '{"token": "valid"}') }

    it "returns true if API responds with token info" do
      allow(client_double).to receive(:api_request)
        .with(method: "GET", path: "/oauth/v1/access-tokens/#{connection.access_token}")
        .and_return(api_response)

      expect(service.test_connection).to be true
    end

    it "returns false on API error" do
      allow(client_double).to receive(:api_request).and_raise(StandardError, "Network error")

      expect(service.test_connection).to be false
    end
  end

  describe "#export_data" do
    let(:client) { create(:client, email: "test@example.com", company_name: "Test Co") }
    let(:data) { { mapped: "data" } }

    let(:company_mapper_double) { instance_double(Crm::Hubspot::CompanyMapper, to_hubspot_properties: { name: "Test Co" }) }
    let(:contact_mapper_double) { instance_double(Crm::Hubspot::ContactMapper, to_hubspot_properties: { email: "test@example.com" }) }
    let(:file_uploader_double) { instance_double(Crm::Hubspot::FileUploader) }

    let(:companies_api_double) { double("CompaniesApi") }
    let(:companies_search_api_double) { double("CompaniesSearchApi") }
    let(:contacts_api_double) { double("ContactsApi") }
    let(:contacts_search_api_double) { double("ContactsSearchApi") }

    before do
      # Ensure Hubspot::ApiError constant exists in test environment
      stub_const("Hubspot::ApiError", Class.new(StandardError))
      allow(Crm::Hubspot::CompanyMapper).to receive(:new).with(client, data).and_return(company_mapper_double)
      allow(Crm::Hubspot::ContactMapper).to receive(:new).with(client, data).and_return(contact_mapper_double)
      allow(Crm::Hubspot::FileUploader).to receive(:new).with(client_double).and_return(file_uploader_double)

      allow(client_double).to receive(:companies_api).and_return(companies_api_double)
      allow(client_double).to receive(:companies_search_api).and_return(companies_search_api_double)
      allow(client_double).to receive(:contacts_api).and_return(contacts_api_double)
      allow(client_double).to receive(:contacts_search_api).and_return(contacts_search_api_double)
      allow(client_double).to receive(:api_request) # for association
    end

    context "when creating new records" do
      it "updates the existing linked contact and returns success" do
        # Ensure client is linked to an external contact
        create(:crm_client_link, client: client, crm_connection: connection, external_contact_id: "cont_456")

        # Simulate successful update response
        allow(client_double).to receive(:api_request).and_return(double(code: 200, body: '{}'))

        result = service.export_data(client, data, [])

        expect(result[:success]).to be true
        expect(result[:external_id]).to eq("cont_456")
        expect(result[:details][:contact][:action]).to eq(:updated)
      end
    end


    context "when creating new company and associating" do
      it "creates the company and associates it with the contact" do
        allow(client_double).to receive(:api_request).and_return(double(code: 200, body: '{}'))
        create(:crm_client_link, client: client, crm_connection: connection, external_contact_id: "cont_456", external_company_id: nil)
        
        allow(client_double).to receive(:api_request).with(
          hash_including(method: "POST", path: %r{/contacts/v1/contact/vid/cont_456/profile})
        ).and_return(double(code: 200, body: '{}'))

        allow(service).to receive(:search_company).and_return(nil)
        
        allow(client_double).to receive(:api_request).with(
          hash_including(method: "POST", path: "/crm/v3/objects/companies")
        ).and_return(double(code: 201, body: %Q({"id":"comp_456"})))

        expect(client_double).to receive(:api_request).with(
          hash_including(method: "PUT", path: "/crm/v3/objects/contacts/cont_456/associations/companies/comp_456/1")
        ).and_return(double(code: 200, body: '{}'))

        company_data = { domain: "test.com" }
        company_mapper_double2 = instance_double(Crm::Hubspot::CompanyMapper, to_hubspot_properties: { name: "Test Co", domain: "test.com" })
        allow(Crm::Hubspot::CompanyMapper).to receive(:new).with(client, company_data).and_return(company_mapper_double2)

        result = service.export_data(client, data, [], company_data: company_data)

        unless result[:success]
          puts "[DEBUG] Export failed: #{result[:error]}"
        end

        expect(result[:success]).to be true
        expect(result[:details][:company][:action]).to eq(:created)
        expect(result[:details][:company][:id]).to eq("comp_456")
        expect(result[:details][:association][:action]).to eq(:linked)
      end
    end

    context "when creating new company and associating" do
      it "creates the company and associates it with the contact" do
        allow(client_double).to receive(:api_request).and_return(double(code: 200, body: '{}'))
        create(:crm_client_link, client: client, crm_connection: connection, external_contact_id: "cont_456", external_company_id: nil)
        
        allow(client_double).to receive(:api_request).with(
          hash_including(method: "POST", path: %r{/contacts/v1/contact/vid/cont_456/profile})
        ).and_return(double(code: 200, body: '{}'))

        allow(service).to receive(:search_company).and_return(nil)
        
        allow(client_double).to receive(:api_request).with(
          hash_including(method: "POST", path: "/crm/v3/objects/companies")
        ).and_return(double(code: 201, body: %Q({"id":"comp_456"})))

        expect(client_double).to receive(:api_request).with(
          hash_including(method: "PUT", path: "/crm/v3/objects/contacts/cont_456/associations/companies/comp_456/1")
        ).and_return(double(code: 200, body: '{}'))

        company_data = { domain: "test.com" }
        company_mapper_double2 = instance_double(Crm::Hubspot::CompanyMapper, to_hubspot_properties: { name: "Test Co", domain: "test.com" })
        allow(Crm::Hubspot::CompanyMapper).to receive(:new).with(client, company_data).and_return(company_mapper_double2)

        result = service.export_data(client, data, [], company_data: company_data)

        unless result[:success]
          puts "[DEBUG] Export failed: #{result[:error]}"
        end

        expect(result[:success]).to be true
        expect(result[:details][:company][:action]).to eq(:created)
        expect(result[:details][:company][:id]).to eq("comp_456")
        expect(result[:details][:association][:action]).to eq(:linked)
      end
    end
    context "when creating new records with files" do
      it "updates linked contact and uploads attached files" do
        create(:crm_client_link, client: client, crm_connection: connection, external_contact_id: "cont_with_files")

        allow(client_double).to receive(:api_request).and_return(double(code: 200, body: '{}'))

        uploaded_file = double("UploadedFile", file: double(attached?: true))
        unattached_file = double("UploadedFile", file: double(attached?: false))

        allow(file_uploader_double).to receive(:upload)
          .with(uploaded_file, associate_to_contact: "cont_with_files")
          .and_return({ file_id: "hubspot_file_1" })

        result = service.export_data(client, data, [ uploaded_file, unattached_file ])

        expect(result[:success]).to be true
        expect(result[:details][:files]).to eq([ { file_id: "hubspot_file_1" } ])
      end
    end

    context "when updating existing records" do
      it "updates the existing linked contact" do
        company_result = double("Result", id: "comp_999")
        contact_result = double("Result", id: "cont_999")

        create(:crm_client_link, client: client, crm_connection: connection, external_contact_id: "cont_999")

        allow(companies_search_api_double).to receive(:do_search).and_return(double(results: [ company_result ]))
        allow(contacts_search_api_double).to receive(:do_search).and_return(double(results: [ contact_result ]))

        allow(client_double).to receive(:api_request).and_return(double(code: 200, body: '{}'))

        result = service.export_data(client, data, [])

        expect(result[:success]).to be true
        expect(result[:details][:contact][:action]).to eq(:updated)
      end
    end

    context "when an API error occurs" do
      it "rescues and returns an error response" do
        # Stub the ApiError class if it doesn't exist to prevent NameError
        # In a real environment hubspot-api-client provides it
        stub_const("Hubspot::ApiError", Class.new(StandardError))
        error = Hubspot::ApiError.new("API Failure")

        create(:crm_client_link, client: client, crm_connection: connection, external_contact_id: "err_1")

        allow(client_double).to receive(:api_request).and_raise(error)

        result = service.export_data(client, data, [])

        expect(result[:success]).to be false
        expect(result[:error]).to eq("API Failure")
      end
    end

    context "when token is expired" do
      it "refreshes token before exporting" do
        connection.update!(expires_at: 1.day.ago)

        allow(service).to receive(:refresh_token!)

        # Setup mocks to prevent crash when export proceeds
        company_result = double("Result", id: "comp_999")
        allow(companies_search_api_double).to receive(:do_search).and_return(double(results: [ company_result ]))
        allow(companies_api_double).to receive(:update).and_return(true)
        allow(contacts_search_api_double).to receive(:do_search).and_return(double(results: []))
        allow(contacts_api_double).to receive(:create).and_return(double(id: "cont_new"))
        create(:crm_client_link, client: client, crm_connection: connection, external_contact_id: "cont_new")
        allow(client_double).to receive(:api_request).and_return(double(code: 200, body: '[]'))

        service.export_data(client, data, [])

        expect(service).to have_received(:refresh_token!)
      end
    end
  end

  describe "fetching and searching data" do
    let(:data_fetcher_double) { instance_double(Crm::Hubspot::DataFetcher) }

    before do
      allow(Crm::Hubspot::DataFetcher).to receive(:new).with(client_double).and_return(data_fetcher_double)
    end

    describe "#fetch_contacts" do
      it "delegates to data fetcher" do
        allow(data_fetcher_double).to receive(:fetch_contacts).with(limit: 50, after: "123").and_return([])
        expect(service.fetch_contacts(limit: 50, after: "123")).to eq([])
      end
    end

    describe "#fetch_companies" do
      it "delegates to data fetcher" do
        allow(data_fetcher_double).to receive(:fetch_companies).with(limit: 50, after: "123").and_return([])
        expect(service.fetch_companies(limit: 50, after: "123")).to eq([])
      end
    end

    describe "#search_contact_by_email" do
      it "delegates to data fetcher" do
        allow(data_fetcher_double).to receive(:search_contact_by_email).with("test@example.com").and_return({ id: "1" })
        expect(service.search_contact_by_email("test@example.com")).to eq({ id: "1" })
      end
    end
  end
end
