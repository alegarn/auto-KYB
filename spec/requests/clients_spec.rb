require "rails_helper"

RSpec.describe "Clients API", type: :request do
  let(:user) { create(:user) }
  let(:session) { user.sessions.create! }

  before do
    cookies.signed[:session_token] = session.id
  end

  describe "GET /clients" do
    it "returns paginated clients for current user" do
      my_clients = create_list(:client, 15, user: user)
      other = create(:user)
      create_list(:client, 3, user: other)

      get clients_path, params: { page: 1 }

      expect(response).to have_http_status(:ok)
      # first page should include 10 of the 15 created for user
      my_clients.first(10).each do |c|
        expect(response.body).to include(c.name)
      end
      # ensure other user's clients are not present
      other_client = Client.where(user_id: other.id).first
      expect(response.body).not_to include(other_client.name)
    end

    it "filters by search query" do
      matching = create(:client, name: "UniqueNameTest", user: user)
      create(:client, name: "Other", user: user)

      get clients_path, params: { q: "UniqueNameTest" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UniqueNameTest")
    end

    it "returns empty props when unauthenticated" do
      cookies.signed[:session_token] = nil

      get clients_path

      expect(response).to have_http_status(:ok)
      # Controller renders inertia with user: nil and clients: [] when no current_user
      expect(response.body).to include("Clients/Index")
    end
  end

  describe "GET /clients/:id" do
    it "shows a client owned by current_user" do
      client = create(:client, user: user)

      get client_path(client)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(client.name)
    end

    it "returns 404 for a client not owned by current_user" do
      other = create(:client)

      expect {
        get client_path(other)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /clients/new" do
    it "renders the new client form" do
      get new_client_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Clients/New")
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

    it "renders errors for invalid attributes" do
      attrs = attributes_for(:client, :invalid)

      post clients_path, params: { client: attrs }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Clients/New")
    end
  end

  describe "GET /clients/:id/edit" do
    it "renders the edit form for owned client" do
      client = create(:client, user: user)

      get edit_client_path(client)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(client.name)
    end

    it "returns 404 when editing another user's client" do
      other = create(:client)

      expect {
        get edit_client_path(other)
      }.to raise_error(ActiveRecord::RecordNotFound)
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

      expect {
        delete client_path(other)
      }.to raise_error(ActiveRecord::RecordNotFound)
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
      expect(response.body).to include("id,name,company_name")
      expect(response.body).to include(client.id.to_s)
    end

    it "returns 404 for another user's client export" do
      other = create(:client)

      expect {
        get "/clients/#{other.id}/export", params: { format: :json }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
