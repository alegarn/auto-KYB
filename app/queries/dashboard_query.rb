class DashboardQuery

  def initialize(user)
    @user = user
  end
  def stats
    {
      total_clients: client_scope.count,
      validated_clients: client_scope.where(form_status: "validated").count,
      active_clients: client_scope.where(form_status: "active").count,
      linked_clients: client_scope.where(form_status: "linked").count
    }
  end

  def recent_forms(limit: 5)
    form_scope.order(updated_at: :desc).limit(limit)
  end

  def clients_scope
    client_scope
  end

  private

  def client_scope
    @client_scope ||= (
      @user.respond_to?(:clients) ? @user.clients : Client.none
    )
  end

  def form_scope
    @form_scope ||= (
      @user.respond_to?(:forms) ? @user.forms : Form.none
    )
  end

end
