require "csv"

class ClientExportService

  ATTRS = %w[name company_name company_id country email phone address created_at updated_at].freeze

  def self.call(client)
    new(client).call
  end

  def initialize(client)
    @client = client
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << ATTRS
      csv << ATTRS.map { |a| @client.as_json[a] }
    end
  end

end
