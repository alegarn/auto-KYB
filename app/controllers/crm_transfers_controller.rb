class CrmTransfersController < ApplicationController
  before_action :authorize_subscription
  before_action :mark_crm_transfer_signals_seen!, only: :index
  before_action :set_transfer, only: :retry

  def index
    scope = current_user_transfers.within_retention_window.newest_first
    scope = scope.by_status(filter_params[:status])
    scope = scope.by_provider(filter_params[:provider])
    scope = scope.by_trigger(filter_params[:trigger])
    @pagy, transfers = pagy(scope, limit: 10, page: params[:page])

    render inertia: "CrmTransfers/Index", props: default_inertia_props.merge(
      transfers: CrmTransferSerializer.collection(transfers),
      filters: filter_params,
      filter_options: {
        statuses: CrmTransfer::STATUSES,
        providers: CrmConnection::PROVIDERS,
        triggers: CrmTransfer::TRIGGERS
      },
      retention_days: CrmTransfer::RETENTION_PERIOD / 1.day,
      meta: {
        page: @pagy.page,
        per_page: @pagy.limit,
        total_count: @pagy.count
      }
    )
  end

  def retry
    unless @transfer.retryable?
      redirect_to crm_transfers_path(redirect_params), alert: "Only failed retryable transfers can be retried.", status: :see_other
      return
    end

    Crm::TransferScheduler.retry!(@transfer)

    redirect_to crm_transfers_path(redirect_params), notice: "CRM transfer retry queued.", status: :see_other
  end

  private

  def authorize_subscription
    authorize :client, :index?
  end

  def set_transfer
    @transfer = current_user_transfers.find(params[:id])
  end

  def current_user_transfers
    CrmTransfer
      .includes(:client, :crm_connection)
      .where(
        client_id: current_user.clients.select(:id),
        crm_connection_id: current_user.crm_connections.select(:id)
      )
  end

  def filter_params
    @filter_params ||= params.permit(:status, :provider, :trigger).to_h.transform_values do |value|
      value.presence
    end
  end

  def redirect_params
    params.permit(:page, :status, :provider, :trigger)
  end

  def mark_crm_transfer_signals_seen!
    seen_at = Time.current

    current_user.update_column(:crm_transfers_last_seen_at, seen_at) if current_user.has_attribute?(:crm_transfers_last_seen_at)
    advance_crm_transfer_toast_marker!(seen_at)
  end
end
