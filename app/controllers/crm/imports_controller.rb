class Crm::ImportsController < ApplicationController
  before_action :authorize_crm_access!

  def index
    authorize :subscription, :index?
    query = params[:q]

    if query.blank? || !current_user.crm_connections.active.exists?
      render json: []
      return
    end

    connection = current_user.crm_connections.active.first
    service = Crm::ConnectionManager.service_for(connection)

    results = if params[:type] == "companies"
                service.search_companies(query)
    else
                service.search_contacts(query)
    end

    render json: results
  rescue => e
    Rails.logger.error("CRM Search Failed: #{e.message}")
    render json: { error: "Failed to search CRM" }, status: :unprocessable_entity
  end

end
