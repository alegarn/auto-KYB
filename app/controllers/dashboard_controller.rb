class DashboardController < ApplicationController

  def index
    authorize :dashboard, :show?
    q = DashboardQuery.new(current_user)
    @pagy, clients_page = pagy(q.clients_scope.order(created_at: :desc), items: 10, page: params[:page])
    clients = ClientSerializer.collection(clients_page)

    render inertia: "Dashboard/Dashboard", props: default_inertia_props.merge(
      clients: clients,
      recent_forms: FormSerializer.collection(q.recent_forms),
      stats: q.stats,
      onboarding: InertiaRails.defer { q.onboarding_summary },
      meta: {
        page: @pagy.page,
        per_page: (@pagy.vars[:items] || clients_page.size),
        total_count: q.total_clients_count
      }
    )
  end

  private
  # `current_user` and `current_session_id` provided by ApplicationController

end
