class ClientSerializer

  def initialize(client)
    @client = client
  end

  def as_json(*)
    data = @client.as_json(only: %i[id name company_name company_id country email phone address])
    data["created_at"] = @client.created_at&.strftime("%Y-%m-%d %H:%M:%S")
    data["updated_at"] = @client.updated_at&.strftime("%Y-%m-%d %H:%M:%S")
    data["status"] = @client.form_status.presence || "inactive"
    data
  end

  def self.collection(relation)
    relation.map { |c| new(c).as_json }
  end

end
