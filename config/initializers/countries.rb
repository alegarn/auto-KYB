require "yaml"

path = Rails.root.join("config/countries.yml")
raw = YAML.load_file(path) || []

# Normalize countries: ensure `name`, uppercase 2-letter `code`, `is_automated`, and compute emoji `flag` when possible.
COUNTRIES = raw.map do |c|
  name = c["name"] || c[:name]
  code_raw = c["code"] || c["iso"] || c[:code] || c[:iso] || ""
  code = code_raw.to_s.strip.upcase
  # compute flag emoji for 2-letter codes
  flag = if code && code.length == 2 && code.match?(/^[A-Z]{2}$/)
    code.each_char.map { |ch| 0x1F1E6 + ch.ord - "A".ord }.pack("U*")
  else
    nil
  end

  {
    "name" => name,
    "code" => code,
    "is_automated" => !!(c["is_automated"] || c[:is_automated]),
    "flag" => flag
  }
end

# Sort by name (case-insensitive) to provide a stable, alphabetical list
COUNTRIES.sort_by! { |c| (c["name"] || "").to_s.downcase }
COUNTRIES.freeze

# Options for selects (name, code)
COUNTRY_OPTIONS = COUNTRIES.map { |c| [ c["name"], c["code"] ] }.freeze

# Lookup by uppercase code
COUNTRIES_BY_CODE = COUNTRIES.index_by do |c|
  c["code"]
end.freeze
