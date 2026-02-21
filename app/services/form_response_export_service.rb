require "csv"

class FormResponseExportService

  def self.call(client_form)
    new(client_form).call
  end

  def self.as_json_payload(client_form)
    new(client_form).as_json_payload
  end

  def initialize(client_form)
    @client_form = client_form
  end

  # Build CSV explicitly using CSV.generate_line and join with CRLF to avoid platform-specific newline issues
  def call
    CSV.generate(row_sep: "\r\n") do |csv|
      csv << build_header(form_fields)

      form_responses.each do |response|
        csv << build_row(response, form_fields)
      end
    end
  end

  def as_json_payload
    {
      client_form: {
        id: @client_form.id,
        form_name: @client_form.form.name,
        client_name: @client_form.client.name
      },
      fields: form_fields.map { |f| { id: f.id, label: f.label, export_key: f.metadata&.dig("export_key").presence || f.label, field_type: f.field_type } },
      responses: form_responses.map do |response|
        {
          # version: response.version, --- IGNORE ---
          created_at: response.created_at.iso8601,
          data: extract_data_by_labels(response.data || {}, form_fields)
        }
      end
    }
  end

  private

  def build_header(form_fields)
    # ignore version in export
    [ "Created At" ] + form_fields.map { |f| f.metadata&.dig("export_key").presence || f.label }
  end

  def build_row(response, form_fields)
    data = response.data || {}

    values = form_fields.map do |field|
      format_for_csv(data[field.id.to_s])
    end

    # ignore version in export
    [ response.created_at.iso8601 ] + values
  end

  def extract_data_by_labels(data, form_fields)
    result = {}
    form_fields.each do |field|
      result[field.id.to_s] = {
        label: field.label,
        export_key: field.metadata&.dig("export_key").presence || field.label,
        value: data[field.id.to_s]
      }
    end
    result
  end

  def form_responses
    # Order by creation time; version is not exported anymore
    @form_responses ||= @client_form.form_responses.order(:created_at)
  end

  def form_fields
    @form_fields ||= @client_form.form.form_fields.order(:position)
  end

  def format_for_csv(value)
    case value
    when Array
      value.join("; ")
    when Hash
      value.map { |k, v| "#{k}: #{v}" }.join("; ")
    when NilClass
      ""
    else
      value.to_s
    end
  end

end
