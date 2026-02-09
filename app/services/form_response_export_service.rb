require 'csv'

class FormResponseExportService
  def self.call(client_form)
    new(client_form).call
  end

  def self.to_json(client_form)
    new(client_form).to_json
  end

  def initialize(client_form)
    @client_form = client_form
  end

  # Build CSV explicitly using CSV.generate_line and join with CRLF to avoid platform-specific newline issues
  def call
    form_responses = @client_form.form_responses.order(:version)
    form_fields = @client_form.form.form_fields.order(:position)

    lines = []
    lines << CSV.generate_line(build_header(form_fields))

    form_responses.each do |response|
      lines << CSV.generate_line(build_row(response, form_fields))
    end

    # Join with CRLF and ensure file ends with newline
    lines.join("\r\n") + "\r\n"
  end

  def to_json
    form_responses = @client_form.form_responses.order(:version)
    form_fields = @client_form.form.form_fields.order(:position)

    {
      client_form: {
        id: @client_form.id,
        form_name: @client_form.form.name,
        client_name: @client_form.client.name
      },
      fields: form_fields.map { |f| { id: f.id, label: f.label, field_type: f.field_type } },
      responses: form_responses.map do |response|
        {
          version: response.version,
          created_at: response.created_at.iso8601,
          data: extract_data_by_labels(response.data || {}, form_fields)
        }
      end
    }
  end

  private

  def build_header(form_fields)
    ['Version', 'Created At'] + form_fields.map(&:label)
  end

  def build_row(response, form_fields)
    data = response.data || {}

    values = form_fields.map do |field|
      format_for_csv(data[field.id.to_s])
    end

    [response.version, response.created_at.iso8601] + values
  end

  def extract_data_by_labels(data, form_fields)
    result = {}
    form_fields.each do |field|
      result[field.label] = data[field.id.to_s]
    end
    result
  end

  def format_for_csv(value)
    case value
    when Array
      value.join('; ')
    when Hash
      value.map { |k, v| "#{k}: #{v}" }.join('; ')
    when NilClass
      ''
    else
      value.to_s
    end
  end
end
