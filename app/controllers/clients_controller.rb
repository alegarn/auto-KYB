require 'csv'

class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy export]

  def index
    return render inertia: 'Clients/Index', props: { user: nil, clients: [] } unless current_user

    scope = Client.by_user(current_user.id).order(created_at: :desc)
    scope = scope.search_by_name_or_company(params[:q]) if params[:q].present?

    @pagy, clients_page = pagy(scope, items: 10, page: params[:page])
    clients = clients_page.map { |c| ClientSerializer.new(c).as_json }

    render inertia: 'Clients/Index', props: {
      user: user_props,
      clients: clients,
      meta: {
        page: @pagy.page,
        per_page: (@pagy.vars[:items] || clients_page.size),
        total_count: scope.count
      }
    }
  end

  def show
    render inertia: 'Clients/Show', props: {
      user: user_props,
      client: ClientSerializer.new(@client).as_json
    }
  end

  # GDPR export endpoint - returns JSON or CSV representation of the client
  def export
    client = current_user.clients.find(params[:id])

    respond_to do |format|
      format.json { render json: ClientSerializer.new(client).as_json }

      format.csv do
        attrs = %w[id name company_name email phone address created_at updated_at]
        csv_data = CSV.generate(headers: true) do |csv|
          csv << attrs
          csv << attrs.map { |a| client.as_json[a] }
        end

        send_data csv_data, filename: "client-#{client.id}.csv", type: 'text/csv'
      end

      # fallback for non-explicit formats
      format.any { render json: ClientSerializer.new(client).as_json }
    end
  end

  def new
    render inertia: 'Clients/New', props: {
      user: user_props,
      client: {}
    }
  end

  def create
    client = current_user.clients.new(client_params)

    if client.save
      redirect_to clients_path, status: :see_other
    else
      render inertia: 'Clients/New', props: {
        user: user_props,
        client: ClientSerializer.new(client).as_json,
        errors: client.errors.messages
      }, status: :unprocessable_entity
    end
  end

  def edit
    render inertia: 'Clients/Edit', props: {
      client: ClientSerializer.new(@client).as_json
    }
  end

  def update
    @client.update!(client_params)

    redirect_to client_path(@client), notice: 'Client updated'
  rescue ActiveRecord::RecordInvalid => e
    render inertia: 'Clients/Edit', props: {
      client: @client.present? ? ClientSerializer.new(@client).as_json : nil,
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def destroy
    @client.destroy!

    redirect_to clients_path, notice: 'Client deleted', status: :see_other
  end

  private

  def client_params
    params.require(:client).permit(:name, :company_name, :email, :phone, address: {})
  end

  def set_client
    @client = current_user.clients.find(params[:id])
  end

  def user_props
    current_user ? { id: current_user.id, email: current_user.email } : nil
  end
end
