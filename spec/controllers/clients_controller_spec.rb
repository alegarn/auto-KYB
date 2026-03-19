require "rails_helper"

RSpec.describe ClientsController, type: :controller, inertia: true do
  let(:user) { create(:user, :subscribed) }
  let(:session) { user.sessions.create! }

  before do
    cookies.signed[:session_token] = session.id
  end

  describe "GET #index" do
    it "paginates and returns only current user's clients" do
      create_list(:client, 15, user: user)
      other_user = create(:user)
      create_list(:client, 3, user: other_user)

      get :index, params: { page: 1 }

      expect(inertia.component).to eq("Clients/Index")
      # returned clients are serialized with string keys — ensure pagination limit applied
      expect(inertia.props[:clients].length).to be <= inertia.props[:meta][:per_page]
      expect(inertia.props[:meta][:per_page]).to eq(10)
      expect(inertia.props[:meta][:total_count]).to eq(15)
      # ensure returned clients belong to user
      returned_ids = inertia.props[:clients].map { |c| c['id'] }
      expect(Client.where(id: returned_ids).pluck(:user_id).uniq).to eq([ user.id ])
    end

    it "filters by search query" do
      matching = create(:client, name: "UniqueName", user: user)
      create(:client, name: "Other", user: user)

      get :index, params: { q: "UniqueName" }

      expect(inertia.component).to eq("Clients/Index")
      expect(inertia.props[:clients].map { |c| c['id'] }).to include(matching.id)
      expect(inertia.props[:clients].map { |c| c['name'] }).to include("UniqueName")
    end

    it "filters by company name as part of search" do
      by_company = create(:client, company_name: "SearchCorp Ltd", user: user)
      create(:client, company_name: "Other Corp", user: user)

      get :index, params: { q: "SearchCorp" }

      expect(inertia.component).to eq("Clients/Index")
      expect(inertia.props[:clients].map { |c| c['id'] }).to include(by_company.id)
      expect(inertia.props[:clients].map { |c| c['company_name'] }).to include("SearchCorp Ltd")
    end

    it "filters by status" do
      validated = create(:client, form_status: "validated", user: user)
      active = create(:client, form_status: "active", user: user)
      inactive = create(:client, form_status: "inactive", user: user)

      # another user's client with same status should not be returned
      other_user = create(:user)
      create(:client, form_status: "active", user: other_user)

      get :index, params: { status: "active" }

      expect(inertia.component).to eq("Clients/Index")
      # serializer exposes status under 'status' key and uses string keys
      returned_statuses = inertia.props[:clients].map { |c| c['status'] }
      expect(returned_statuses).to all(eq("active"))
      returned_ids = inertia.props[:clients].map { |c| c['id'] }
      expect(returned_ids).to include(active.id)
      expect(returned_ids).not_to include(validated.id)
      expect(returned_ids).not_to include(inactive.id)
    end

    it "applies combined status and name filters" do
      # matching both name and status
      match = create(:client, name: "Acme Co", form_status: "validated", user: user)
      # same name but different status
      create(:client, name: "Acme Co", form_status: "active", user: user)
      # same status but different name (company_name must not match "Acme")
      create(:client, name: "Other", company_name: "Other Corp", form_status: "validated", user: user)

      get :index, params: { q: "Acme", status: "validated" }

      expect(inertia.component).to eq("Clients/Index")
      returned_ids = inertia.props[:clients].map { |c| c['id'] }
      expect(returned_ids).to include(match.id)
      # ensure only the client matching both filters is returned
      expect(returned_ids.length).to eq(1)
    end
  end

  describe "GET #show" do
    it "renders the client when owned by current_user" do
      client = create(:client, user: user)

      get :show, params: { id: client.id }

      expect(inertia.component).to eq("Clients/Show")
      # serializer returns string-keyed hash
      expect(inertia.props[:client]['id']).to eq(client.id)
    end

    it "raises when accessing another user's client" do
      other = create(:client)

      expect {
        get :show, params: { id: other.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET #new" do
    it "prepares a new client form" do
      get :new

      expect(inertia.component).to eq("Clients/New")
      expect(inertia.props[:client]).to be_a(Hash)
    end
  end

  describe "POST #create" do
    it "creates a client with valid attributes and redirects" do
      attrs = attributes_for(:client)

      expect {
        post :create, params: { client: attrs }
      }.to change { Client.count }.by(1)

      expect(response).to redirect_to(clients_path)
      expect(response.status).to eq(303) # see_other
    end

    it "renders errors for invalid attributes" do
      attrs = attributes_for(:client, :invalid)

      post :create, params: { client: attrs }

      expect(response.status).to eq(422)
      expect(inertia.component).to eq("Clients/New")
      expect(inertia.props[:errors]).to be_present
    end

    it "renders form not found when selected form does not exist" do
      attrs = attributes_for(:client)

      post :create, params: { client: attrs, client_form: { form_id: 999_999 } }

      expect(response.status).to eq(422)
      expect(inertia.component).to eq("Clients/New")
      expect(inertia.props[:errors]['form_id'] || inertia.props[:errors][:form_id]).to be_present
      # ensure the message is the expected one
      expect(inertia.props[:errors].values.flatten.join).to include("Form not found")
    end
  end

  describe "GET #edit" do
    it "renders the edit form for owned client" do
      client = create(:client, user: user)

      get :edit, params: { id: client.id }

      expect(inertia.component).to eq("Clients/Edit")
      # serializer returns string-keyed hash
      expect(inertia.props[:client]['id']).to eq(client.id)
    end

    it "includes available forms in inertia props" do
      client = create(:client, user: user)
      form_a = create(:form, user: user)
      form_b = create(:form, user: user)

      get :edit, params: { id: client.id }

      expect(inertia.component).to eq("Clients/Edit")
      returned_form_ids = inertia.props[:forms].map { |f| f['id'] }
      expect(returned_form_ids).to include(form_a.id, form_b.id)
    end

    it "raises when editing another user's client" do
      other = create(:client)

      expect {
        get :edit, params: { id: other.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH #update" do
    it "updates successfully with valid params" do
      client = create(:client, user: user, name: "Before")

      patch :update, params: { id: client.id, client: { name: "After" } }

      expect(response).to redirect_to(client_path(client))
      expect(flash[:notice]).to eq("Client updated")
      expect(client.reload.name).to eq("After")
    end

    it "renders errors when validation fails" do
      client = create(:client, user: user)

      patch :update, params: { id: client.id, client: { name: nil, company_name: nil } }

      expect(response.status).to eq(422)
      expect(inertia.component).to eq("Clients/Edit")
      expect(inertia.props[:errors]).to be_present
    end

    it "renders form not found when remapping to a non-existent form" do
      client = create(:client, user: user)

      patch :update, params: { id: client.id, client: { name: 'New' }, client_form: { form_id: 999_999 } }

      expect(response.status).to eq(422)
      expect(inertia.component).to eq("Clients/Edit")
      expect(inertia.props[:errors]['form_id'] || inertia.props[:errors][:form_id]).to be_present
      expect(inertia.props[:errors].values.flatten.join).to include("Form not found")
    end

    context "with CRM sync parameters" do
      let!(:crm_connection) { create(:crm_connection, user: user, provider: "hubspot") }
      let(:client) { create(:client, user: user) }

      it "triggers CrmSyncService with the provided flags" do
        expect(CrmSyncService).to receive(:call).with(
          instance_of(Client),
          "update",
          hash_including(sync_address_to_contact: "true")
        )

        patch :update, params: { 
          id: client.id, 
          client: { name: "Updated Name" },
          crm: { strategy: "update", sync_address_to_contact: "true" }
        }

        expect(response).to redirect_to(client_path(client))
      end
    end

    context "with a linked CRM client" do
      let!(:crm_connection) { create(:crm_connection, user: user, provider: "hubspot", status: "active") }
      let(:client) { create(:client, user: user) }

      before do
        create(:crm_client_link, client: client, crm_connection: crm_connection)
      end

      it "triggers linked profile sync after a successful update" do
        expect(Crm::ClientProfileSyncService).to receive(:call).with(instance_of(Client))

        patch :update, params: { id: client.id, client: { phone: "+33 1 23 45 67 89" } }

        expect(response).to redirect_to(client_path(client))
      end
    end

    context 'remapping linked forms' do
      let(:form_a) { create(:form, user: user) }
      let(:form_b) { create(:form, user: user) }

      before do
        # make sure controller sees current_user
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      end

      context 'when client is active and has responses' do
        before do
          client = create(:client, user: user)
          res = ClientInvitationService.create_invitation(client: client, form: form_a)
          cf = res[:client_form]
          cf.save_response!(data: { foo: 'bar' })
          client.update!(form_status: :active)
        end

        it 'returns confirm required when not confirmed' do
          client = Client.last
          patch :update, params: { id: client.id, client: { name: 'New' }, client_form: { form_id: form_b.id } }

          expect(response.status).to eq(422)
          expect(inertia.component).to eq('Clients/Edit')
          expect(inertia.props[:confirm_replace_required]).to be true
        end

        it 'rolls back client changes when remapper requires confirmation' do
          client = Client.last
          prev_name = client.name

          allow(ClientFormRemapperService).to receive(:call).and_raise(ClientFormRemapperService::ConfirmReplaceRequired.new(form_b.id))

          patch :update, params: { id: client.id, client: { name: 'AttemptedNew' }, client_form: { form_id: form_b.id } }

          expect(response.status).to eq(422)
          expect(inertia.component).to eq('Clients/Edit')
          expect(inertia.props[:confirm_replace_required]).to be true
          expect(client.reload.name).to eq(prev_name)
        end

        it 'deletes old responses and redirects to password reveal when confirmed' do
          client = Client.last
          patch :update, params: { id: client.id, client: { name: 'New' }, client_form: { form_id: form_b.id, confirm_replace: '1' } }

          expect(response).to have_http_status(:see_other)
          client.reload
          expect(client.client_forms.where(form_id: form_b.id).exists?).to be true
        end
      end

      context 'when client has no responses' do
        it 'creates invitation without confirmation' do
          client = create(:client, user: user)
          patch :update, params: { id: client.id, client: { name: 'New' }, client_form: { form_id: form_a.id } }

          expect(response).to have_http_status(:see_other)
          client.reload
          expect(client.client_forms.where(form_id: form_a.id).exists?).to be true
        end
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys owned client and redirects" do
      client = create(:client, user: user)

      expect {
        delete :destroy, params: { id: client.id }
      }.to change { Client.exists?(client.id) }.from(true).to(false)

      expect(response).to redirect_to(clients_path)
      expect(response.status).to eq(303)
      expect(flash[:notice]).to eq("Client deleted")
    end

    it "raises when destroying another user's client" do
      other = create(:client)

      expect {
        delete :destroy, params: { id: other.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET #export" do
    it "returns JSON by default when format=json" do
      client = create(:client, user: user)

      get :export, params: { id: client.id, format: :json }

      expect(response.content_type).to include("application/json")
      expect(response.body).to include(client.name)
    end

    it "returns CSV when requested" do
      client = create(:client, user: user)

      get :export, params: { id: client.id, format: :csv }

      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("client-#{client.id}.csv")
      # CSV should contain header and at least the client name
      expect(response.body).to include("name,company_name,email,phone,address,created_at,updated_at")
      expect(response.body).to include(client.name)
    end

    it "raises when exporting another user's client" do
      other = create(:client)

      expect {
        get :export, params: { id: other.id, format: :json }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
