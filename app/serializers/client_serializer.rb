class ClientSerializer
  def initialize(client)
    @client = client
  end

  def as_json(*)
    @client.as_json(only: %i[id name company_name email phone address created_at updated_at])
  end

  def self.collection(relation)
    relation.map { |c| new(c).as_json }
  end
end
