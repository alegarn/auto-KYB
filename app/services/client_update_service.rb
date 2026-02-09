class ClientUpdateService
  Result = Struct.new(:action, :client_form, :password, :message, :attempted_form_id, keyword_init: true) do
    def success?
      action == :success
    end

    def password_reveal?
      action == :password_reveal
    end

    def confirm_replace?
      action == :confirm_replace
    end

    def to_h
      super.compact
    end

    def slice(*keys)
      to_h.slice(*keys)
    end
  end

  def self.call(client:, client_params:, new_form: nil, confirm_replace: false, expires_in: 7.days)
    new(client:, client_params:, new_form:, confirm_replace:, expires_in:).call
  end

  def initialize(client:, client_params:, new_form: nil, confirm_replace: false, expires_in: 7.days)
    @client = client
    @client_params = client_params
    @new_form = new_form
    @confirm_replace = confirm_replace
    @expires_in = expires_in
  end

  def call
    result = Result.new(action: :success)

    ActiveRecord::Base.transaction do
      @client.update!(@client_params)

      if @new_form.present?
        result = handle_form_remap
        raise ActiveRecord::Rollback if result.confirm_replace?
      end
    end

    result
  end

  private

  def handle_form_remap
    service_result = ClientFormRemapperService.call(
      client: @client,
      new_form: @new_form,
      confirm_replace: @confirm_replace,
      expires_in: @expires_in
    )

    if service_result[:status] == :created
      Result.new(
        action: :password_reveal,
        client_form: service_result[:client_form],
        password: service_result[:password]
      )
    else
      Result.new(action: :success)
    end
  rescue ClientFormRemapperService::ConfirmReplaceRequired => e
    Result.new(
      action: :confirm_replace,
      message: e.message,
      attempted_form_id: e.attempted_form_id
    )
  end
end
