require "rails_helper"

RSpec.describe ClientsController, type: :controller, inertia: true do
  let(:user) { create(:user) }
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
      expect(inertia.props[:clients].length).to eq(10)
      expect(inertia.props[:meta][:per_page]).to eq(10)
      expect(inertia.props[:meta][:total_count]).to eq(15)
      # ensure returned clients belong to user
      returned_ids = inertia.props[:clients].map { |c| c[:id] }
      expect(Client.where(id: returned_ids).pluck(:user_id).uniq).to eq([user.id])
    end

    it "filters by search query" do
      matching = create(:client, name: "UniqueName", user: user)
      create(:client, name: "Other", user: user)

      get :index, params: { q: "UniqueName" }

      expect(inertia.component).to eq("Clients/Index")
      expect(inertia.props[:clients].map { |c| c[:id] }).to include(matching.id)
      expect(inertia.props[:clients].map { |c| c[:name] }).to include("UniqueName")
    end
  end

  describe "GET #show" do
    it "renders the client when owned by current_user" do
      client = create(:client, user: user)

      get :show, params: { id: client.id }

      expect(inertia.component).to eq("Clients/Show")
      expect(inertia.props[:client][:id]).to eq(client.id)
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
  end

  describe "GET #edit" do
    it "renders the edit form for owned client" do
      client = create(:client, user: user)

      get :edit, params: { id: client.id }

      expect(inertia.component).to eq("Clients/Edit")
      expect(inertia.props[:client][:id]).to eq(client.id)
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
      # CSV should contain header and at least the client id
      expect(response.body).to include("id,name,company_name")
      expect(response.body).to include(client.id.to_s)
    end

    it "raises when exporting another user's client" do
      other = create(:client)

      expect {
        get :export, params: { id: other.id, format: :json }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
