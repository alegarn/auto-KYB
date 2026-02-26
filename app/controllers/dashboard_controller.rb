class DashboardController < ApplicationController

  def index
    authorize :dashboard, :show?
    q = DashboardQuery.new(current_user)
    @pagy, clients_page = pagy(q.clients_scope.order(created_at: :desc), items: 10, page: params[:page])
    clients = ClientSerializer.collection(clients_page)

    render inertia: "Dashboard/Dashboard", props: {
      user: current_user,
      clients: clients,
      recent_forms: FormSerializer.collection(q.recent_forms),
      stats: q.stats,
      meta: {
        page: @pagy.page,
        per_page: (@pagy.vars[:items] || clients_page.size),
        total_count: q.clients_scope.count
      }
    }
  end

  private
  # `current_user` and `current_session_id` provided by ApplicationController

end
