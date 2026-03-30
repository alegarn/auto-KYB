require "rails_helper"

RSpec.describe "Clients API", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :subscribed, plan: :pro) }
  let(:session) { user.sessions.create! }
  let(:inertia_headers) { { 'X-Inertia' => 'true', 'X-Inertia-Version' => ViteRuby.digest } }

  before do
    cookies.signed[:session_token] = session.id
  end

  around do |example|
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe "GET /clients" do
    it "returns paginated clients for current user" do
      my_clients = create_list(:client, 15, user: user)
      other = create(:user)
      create_list(:client, 3, user: other, name: "Other User Client")

      get clients_path, params: { page: 1 }, headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      names = payload.dig('props', 'clients').map { |c| c['name'] }
      # first page should include 10 of the 15 created for user
      my_clients.first(10).each do |c|
        expect(names).to include(c.name)
      end
      # ensure other user's clients are not present
      other_client = Client.where(user_id: other.id).first
      expect(names).not_to include(other_client.name)
    end

    it "filters by search query" do
      matching = create(:client, name: "UniqueNameTest", user: user)
      create(:client, name: "Other", user: user)

      get clients_path, params: { q: "UniqueNameTest" }, headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      names = payload.dig('props', 'clients').map { |c| c['name'] }
      expect(names).to include(matching.name)
    end

    it "returns empty props when unauthenticated" do
      cookies.signed[:session_token] = nil
      Current.session = nil

      get clients_path

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "GET /clients/:id" do
    it "shows a client owned by current_user" do
      client = create(:client, user: user)

      get client_path(client), headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['component']).to eq('Clients/Show')
      expect(payload.dig('props', 'client', 'name')).to eq(client.name)
    end

    it "returns 404 for a client not owned by current_user" do
      other = create(:client)

      get client_path(other)

      expect(response).to have_http_status(:not_found)
    end

    it "includes file retention metadata in the show props" do
      client = create(:client, user: user)

      get client_path(client), headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      file_retention = payload.dig('props', 'file_retention')
      expect(file_retention['starts_on']).to eq(FileRetentionPolicy::STARTS_ON)
      expect(file_retention['purge_delay_seconds']).to eq(FileRetentionPolicy.purge_delay_seconds)
    end

    it "only lists available uploaded files and exposes purge scheduling" do
      client = create(:client, user: user)

      # available file with scheduled purge
      scheduled_at = 2.days.from_now.change(usec: 0)
      available = create(:uploaded_file, :with_file, client: client, status: "available", purge_scheduled_at: scheduled_at, form_response: nil)

      # downloaded file should not be returned in available list
      create(:uploaded_file, :with_file, :downloaded, client: client, form_response: nil)

      get client_path(client), headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      files = payload.dig('props', 'uploaded_files')
      expect(files.map { |f| f['id'] }).to include(available.id)
      expect(files.map { |f| f['status'] }).to all(eq('available'))
      found = files.find { |f| f['id'] == available.id }
      expect(found['purge_scheduled_at']).to eq(scheduled_at.iso8601)
    end
  end

  describe "GET /clients/new" do
    it "renders the new client form" do
      get new_client_path, headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['component']).to eq("Clients/New")
    end

    it "includes the CRM connection flag in inertia props" do
      create(:crm_connection, user: user, status: "active")

      get new_client_path, headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload.dig("props", "has_active_crm_connection")).to eq(true)
    end
  end

  describe "POST /clients" do
    it "creates a client with valid attributes and redirects" do
      attrs = attributes_for(:client)

      expect {
        post clients_path, params: { client: attrs }
      }.to change { Client.count }.by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(clients_path)
    end

    it "queues async CRM creation instead of calling the provider inline" do
      create(:crm_connection, user: user, provider: "hubspot", status: "active")
      attrs = attributes_for(:client, company_name: "Acme Corp")

      expect(Crm::ConnectionManager).not_to receive(:service_for)

      expect {
        post clients_path, params: {
          client: attrs,
          crm: {
            strategy: "create",
            sync_address_to_contact: "true",
            external_company_id: "comp_existing"
          }
        }
      }.to change(Client, :count).by(1)
        .and change(CrmTransfer, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(clients_path)
      expect(flash[:notice]).to eq("Client created. CRM sync was queued and will continue in the background.")

      transfer = CrmTransfer.order(created_at: :desc).first
      expect(transfer).to have_attributes(
        status: CrmTransfer::STATUS_PENDING,
        trigger: CrmTransfer::TRIGGER_CLIENT_CREATE_SYNC
      )
      expect(transfer.request_context).to include(
        "source" => "clients#create",
        "sync_address_to_contact" => true,
        "external_company_id" => "comp_existing"
      )
      expect(enqueued_jobs.select { |job| job[:job] == CrmDataExportJob }.map { |job| job[:args] }).to contain_exactly([transfer.id])
    end

    it "renders errors for invalid attributes" do
      attrs = attributes_for(:client, :invalid)

      post clients_path, params: { client: attrs }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Clients/New")
    end

    context "when CRM sync is requested by a non-entitled user" do
      let(:user) { create(:user, :subscribed, plan: :basic) }

      before do
        create(:crm_connection, user: user, provider: "hubspot", status: "active")
      end

      it "rejects the request before creating a client or transfer" do
        attrs = attributes_for(:client, company_name: "Acme Corp")

        expect {
          post clients_path, params: {
            client: attrs,
            crm: {
              strategy: "create",
              sync_address_to_contact: "true"
            }
          }
        }.not_to change(Client, :count)

        expect(CrmTransfer.count).to eq(0)
        expect(response).to redirect_to(dashboard_path)
        expect(response).to have_http_status(:see_other)
      end
    end
  end

  describe "GET /clients/:id/edit" do
    it "renders the edit form for owned client" do
      client = create(:client, user: user)

      get edit_client_path(client), headers: inertia_headers

      expect(response).to have_http_status(:ok)

      if response.headers['X-Inertia'] == 'true'
        payload = JSON.parse(response.body)
        expect(payload['component']).to eq("Clients/Edit")
        expect(payload.dig('props', 'client', 'name')).to eq(client.name)
      else
        # fallback for HTML responses
        expect(response.body).to include(client.name)
      end
    end

    it "returns 404 when editing another user's client" do
      other = create(:client)

      get edit_client_path(other)

      expect(response).to have_http_status(:not_found)
    end

    it "includes CRM booleans for an unlinked client without active CRM connection" do
      client = create(:client, user: user)

      get edit_client_path(client), headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload.dig("props", "has_crm_link")).to eq(false)
      expect(payload.dig("props", "has_active_crm_connection")).to eq(false)
    end

    it "includes CRM booleans for a linked client with an active CRM connection" do
      connection = create(:crm_connection, user: user, status: "active")
      client = create(:client, user: user)
      create(:crm_client_link, client: client, crm_connection: connection)

      get edit_client_path(client), headers: inertia_headers

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload.dig("props", "has_crm_link")).to eq(true)
      expect(payload.dig("props", "has_active_crm_connection")).to eq(true)
    end
  end

  describe "PATCH /clients/:id" do
    it "updates successfully with valid params" do
      client = create(:client, user: user, name: "Before")

      patch client_path(client), params: { client: { name: "After" } }

      expect(response).to redirect_to(client_path(client))
      expect(response).to have_http_status(:found)
      expect(client.reload.name).to eq("After")
    end

    it "renders errors when validation fails" do
      client = create(:client, user: user)

      patch client_path(client), params: { client: { name: nil, company_name: nil } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Clients/Edit")
    end

    context "when CRM sync is requested by a non-entitled user" do
      let(:user) { create(:user, :subscribed, plan: :basic) }

      it "rejects the update before changing the client or scheduling work" do
        create(:crm_connection, user: user, provider: "hubspot", status: "active")
        client = create(:client, user: user, name: "Before")

        expect {
          patch client_path(client), params: {
            client: { name: "After" },
            crm: { strategy: "update" }
          }
        }.not_to change(CrmTransfer, :count)

        expect(client.reload.name).to eq("Before")
        expect(response).to redirect_to(dashboard_path)
        expect(response).to have_http_status(:see_other)
      end
    end

    it "enqueues ClientProfileSyncJob in the background when no CRM strategy is provided" do
      client = create(:client, user: user)

      patch client_path(client), params: { client: { name: "Updated" } }

      expect(response).to redirect_to(client_path(client))
      expect(response).to have_http_status(:found)
      expect(enqueued_jobs.map { |j| j[:job] }).to include(ClientProfileSyncJob)
    end

    it "does not enqueue ClientProfileSyncJob when a CRM strategy is provided" do
      client = create(:client, user: user)
      allow(CrmSyncService).to receive(:call)

      patch client_path(client), params: { client: { name: "Updated" }, crm: { strategy: "update" } }

      expect(response).to redirect_to(client_path(client))
      expect(enqueued_jobs.map { |j| j[:job] }).not_to include(ClientProfileSyncJob)
    end

    it "calls CrmSyncService inline when a CRM strategy is present" do
      client = create(:client, user: user)

      expect(CrmSyncService).to receive(:call)

      patch client_path(client), params: { client: { name: "Updated" }, crm: { strategy: "update", external_contact_id: "ext_001" } }

      expect(response).to redirect_to(client_path(client))
    end

    it "renders confirm_replace_required in edit props when form swap needs confirmation" do
      client = create(:client, user: user)
      form_a = create(:form, user: user)
      ClientInvitationService.create_invitation(client: client, form: form_a)
      ClientForm.last.save_response!(data: { a: 1 })
      client.reload

      form_b = create(:form, user: user)

      patch client_path(client), params: {
        client: { name: client.name },
        client_form: { form_id: form_b.id, confirm_replace: "false" }
      }, headers: inertia_headers

      expect(response).to have_http_status(:unprocessable_entity)
      payload = JSON.parse(response.body)
      expect(payload.dig("props", "confirm_replace_required")).to eq(true)
    end

    it "redirects to password_reveal when linking a new form creates a credential" do
      client = create(:client, user: user)
      form = create(:form, user: user)

      patch client_path(client), params: {
        client: { name: client.name },
        client_form: { form_id: form.id }
      }

      expect(response).to have_http_status(:see_other)
      expect(response.location).to include("password_reveal")
    end
  end

  describe "DELETE /clients/:id" do
    it "destroys owned client and redirects" do
      client = create(:client, user: user)

      expect {
        delete client_path(client)
      }.to change { Client.exists?(client.id) }.from(true).to(false)

      expect(response).to redirect_to(clients_path)
      expect(response).to have_http_status(:see_other)
    end

    it "returns 404 when deleting another user's client" do
      other = create(:client)

      delete client_path(other)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /clients/:id/export" do
    it "returns JSON representation when requested" do
      client = create(:client, user: user)

      get "/clients/#{client.id}/export", params: { format: :json }

      expect(response.content_type).to include("application/json")
      expect(response.body).to include(client.name)
    end

    it "returns CSV when requested" do
      client = create(:client, user: user)

      get "/clients/#{client.id}/export", params: { format: :csv }

      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("client-#{client.id}.csv")
      # relax exact header matching; ensure key columns present
      expect(response.body).to include("name")
      expect(response.body).to include("email")
      expect(response.body).to include(client.name)
    end

    it "returns 404 for another user's client export" do
      other = create(:client)

      get "/clients/#{other.id}/export", params: { format: :json }

      expect(response).to have_http_status(:not_found)
    end
  end
end
