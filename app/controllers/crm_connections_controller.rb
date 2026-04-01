# frozen_string_literal: true

class CrmConnectionsController < ApplicationController
  before_action :authorize_crm_access!

  # GET /crm_connections/auth/:provider
  # This route ensures a standard, full-page browser redirect to avoid any Inertia XHR weirdness.
  def auth
    provider = params.require(:provider)
    case provider
    when "hubspot"
      state = SecureRandom.hex(24)
      session[:crm_oauth_state] = state
      oauth = Crm::Hubspot::OAuth.new
      redirect_to oauth.authorize_url(state: state), allow_other_host: true
    else
      redirect_to settings_path, alert: "Unsupported CRM provider."
    end
  end

  # POST /crm_connections?provider=hubspot
  def create
    provider = params.require(:provider)

    case provider
    when "hubspot"
      state = SecureRandom.hex(24)
      session[:crm_oauth_state] = state

      oauth = Crm::Hubspot::OAuth.new
      url = oauth.authorize_url(state: state)
      Rails.logger.warn ">>> GENERATED OAUTH URL: #{url}"
      # inertia_location triggers a hard window.location redirect on the client
      # instead of an XHR follow, which is required for external OAuth flows.
      inertia_location url
    else
      redirect_back fallback_location: settings_path, alert: "Unsupported CRM provider.", status: :see_other
    end
  end

  # GET /crm_connections/:provider/callback?code=...&state=...
  def callback
    provider = params[:provider]

    unless params[:state] == session.delete(:crm_oauth_state)
      redirect_to settings_path, alert: "Invalid OAuth state. Please try again."
      return
    end

    case provider
    when "hubspot"
      handle_hubspot_callback
    else
      redirect_to settings_path, alert: "Unknown provider."
    end
  end

  # DELETE /crm_connections/:id
  def destroy
    connection = current_user.crm_connections.find(params[:id])
    connection.update!(status: "disconnected", access_token: nil, refresh_token: nil)
    redirect_to settings_path, notice: "#{connection.provider.titleize} disconnected."
  end

  # POST /crm_connections/:id/test
  def test
    connection = current_user.crm_connections.find(params[:id])
    service = Crm::ConnectionManager.service_for(connection)

    if service.test_connection
      render json: { success: true, message: "Connection is healthy." }
    else
      render json: { success: false, message: "Connection test failed." }, status: :unprocessable_entity
    end
  rescue => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  private

  def handle_hubspot_callback
    oauth = Crm::Hubspot::OAuth.new
    tokens = oauth.exchange_code(params[:code])

    connection = current_user.crm_connections.find_or_initialize_by(provider: "hubspot")
    connection.assign_attributes(
      access_token:  tokens[:access_token],
      refresh_token: tokens[:refresh_token],
      expires_at:    Time.current + tokens[:expires_in].to_i.seconds,
      status:        "active",
      scopes:        HubspotConfig.scopes
    )
    connection.save!

    redirect_to settings_path, notice: "HubSpot connected successfully!"
  rescue Crm::Hubspot::OAuthError => e
    Rails.logger.error("[HubSpot OAuth] #{e.message}")
    redirect_to settings_path, alert: "Failed to connect HubSpot: #{e.message}"
  end
end
