class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy]

  def index
    clients = if current_user
      current_user.clients.order(created_at: :desc).map { |c| client_json(c) }
    else
      []
    end

    render inertia: 'Clients/Index', props: {
      user: user_props,
      clients: clients
    }
  end

  def show
    render inertia: 'Clients/Show', props: {
      user: user_props,
      client: client_json(@client)
    }
  end

  def new
    render inertia: 'Clients/New', props: {
      user: user_props
    }
  end

  def create
    client = current_user.clients.new(client_params)
    client.save!

    redirect_to clients_path, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    render inertia: 'Clients/New', props: {
      user: user_props,
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def edit
    render inertia: 'Clients/Edit', props: {
      client: client_json(@client)
    }
  end

  def update
    @client.update!(client_params)

    redirect_to client_path(@client), notice: 'Client updated'
  rescue ActiveRecord::RecordInvalid => e
    render inertia: 'Clients/Edit', props: {
      client: @client.present? ? client_json(@client) : nil,
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def destroy
    @client.destroy!

    redirect_to clients_path, status: :see_other
  end

  private

  def client_params
    params.require(:client).permit(:name, :company_name, :email, :phone, address: {})
  end

  def client_json(client)
    client.as_json(only: [:id, :name, :company_name, :email, :phone, :address, :created_at, :updated_at])
  end

  def set_client
    @client = current_user.clients.find(params[:id])
  end

  def user_props
    current_user ? { id: current_user.id, email: current_user.email } : nil
  end
end
