class ClientFormSerializer
  def initialize(client_form)
    @client_form = client_form
  end

  def as_json(*)
    return nil unless @client_form

    {
      'id' => @client_form.id,
      'status' => ClientForm.statuses.key(@client_form.status) || @client_form.status,
      'created_at' => @client_form.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
      'form' => @client_form.form ? FormSerializer.new(@client_form.form).as_json : nil
    }
  end

  def self.collection(relation)
    relation.map { |cf| new(cf).as_json }
  end
end
