class FormJsonValidator

  VALID_FIELD_TYPES = %w[
    text number email date textarea checkbox buttons select radio
    file table section subtitle static_text separator logo
  ].freeze
  CHOICE_FIELD_TYPES = %w[select radio checkbox buttons].freeze
  TABLE_COLUMN_TYPES = %w[text number].freeze
  LAYOUT_FIELD_TYPES = %w[section subtitle static_text separator logo].freeze
  DEFAULT_SETTINGS = {
    "primary_color" => "#2563eb",
    "form_background_color" => "#ffffff",
    "header_background_color" => "#f8fafc"
  }.freeze

  Result = Struct.new(:valid, :data, :warnings, :errors, keyword_init: true)

  def self.call(json)
    payload = stringify_keys(json)
    warnings = []
    errors = []

    errors << "Missing 'name'" if payload["name"].blank?

    structure = payload["structure"]
    unless structure.is_a?(Hash)
      errors << "Missing 'structure'"
      return Result.new(valid: false, data: nil, warnings: [], errors: errors)
    end

    fields = structure["fields"]
    unless fields.is_a?(Array) && fields.any?
      errors << "Missing or empty 'structure.fields'"
      return Result.new(valid: false, data: nil, warnings: [], errors: errors)
    end

    corrected_fields = []
    unknown_type_count = 0

    fields.each_with_index do |field, index|
      unless field.is_a?(Hash)
        errors << "Field at position #{index + 1} must be an object"
        next
      end

      corrected_field, field_warnings, field_errors, defaulted_type = normalize_field(field, index)
      warnings.concat(field_warnings)
      errors.concat(field_errors)
      unknown_type_count += 1 if defaulted_type
      corrected_fields << corrected_field if corrected_field
    end

    export_key_resolution = PdfImportExportKeyResolver.call(corrected_fields)
    corrected_fields = export_key_resolution.fields
    warnings.concat(export_key_resolution.warnings)

    duplicate_export_keys = duplicate_export_keys(corrected_fields)
    errors << "Duplicate export keys: #{duplicate_export_keys.join(', ')}" if duplicate_export_keys.any?

    return Result.new(valid: false, data: nil, warnings: [], errors: errors.uniq) if errors.any?

    warnings << "#{unknown_type_count} field(s) had unknown types and were defaulted to 'text'" if unknown_type_count.positive?

    corrected_data = {
      "name" => payload["name"],
      "structure" => {
        "fields" => corrected_fields,
        "settings" => normalize_settings(structure["settings"])
      }
    }

    description = structure["description"].presence
    corrected_data["structure"]["description"] = description if description.present?

    Result.new(valid: true, data: corrected_data, warnings: warnings.uniq, errors: [])
  end

  def self.normalize_field(field, index)
    warnings = []
    errors = []
    payload = stringify_keys(field)
    label = payload["label"].to_s.strip
    metadata = payload["metadata"]
    metadata = stringify_keys(metadata) if metadata.is_a?(Hash)

    unless metadata.is_a?(Hash)
      metadata = {}
      warnings << "Field '#{label.presence || "Field #{index + 1}"}' had invalid metadata and was reset"
    end

    errors << "Field at position #{index + 1} is missing 'label'" if label.blank?

    field_type = payload["field_type"].to_s
    defaulted_type = false
    unless VALID_FIELD_TYPES.include?(field_type)
      field_type = "text"
      defaulted_type = true
    end

    metadata = normalize_shared_metadata(label, index, metadata, warnings)
    metadata = normalize_choice_metadata(payload, metadata, field_type, warnings)
    metadata = normalize_table_metadata(label, metadata, field_type, warnings)
    metadata = normalize_file_metadata(label, index, metadata, field_type, warnings)
    metadata = normalize_layout_metadata(metadata, field_type)

    corrected_field = {
      "label" => label,
      "field_type" => field_type,
      "required" => ActiveModel::Type::Boolean.new.cast(payload["required"]),
      "position" => index + 1,
      "metadata" => metadata
    }

    [ corrected_field, warnings, errors, defaulted_type ]
  end
  private_class_method :normalize_field

  def self.normalize_shared_metadata(label, index, metadata, warnings)
    export_key = metadata["export_key"].to_s.strip
    if export_key.present?
      metadata["export_key"] = export_key
    else
      metadata.delete("export_key")
    end

    crm_mapping = metadata["crm_mapping"]
    return metadata unless metadata.key?("crm_mapping")

    field_name = label.presence || "Field #{index + 1}"
    unless crm_mapping.is_a?(Hash)
      metadata.delete("crm_mapping")
      warnings << "Field '#{field_name}' had invalid CRM mapping metadata and it was removed"
      return metadata
    end

    normalized_mapping = crm_mapping.each_with_object({}) do |(provider, mapping), memo|
      next if provider.to_s.blank?
      next unless mapping.is_a?(Hash)

      memo[provider.to_s] = stringify_keys(mapping)
    end

    if normalized_mapping.empty?
      metadata.delete("crm_mapping")
      warnings << "Field '#{field_name}' had invalid CRM mapping metadata and it was removed"
    else
      metadata["crm_mapping"] = normalized_mapping
    end

    metadata
  end
  private_class_method :normalize_shared_metadata

  def self.normalize_choice_metadata(field, metadata, field_type, warnings)
    return metadata.except("options", "allow_multiple") unless CHOICE_FIELD_TYPES.include?(field_type)

    options = metadata["options"]
    top_level_options = field["options"]
    normalized_options = if options.is_a?(Array) && options.any?
      options
    elsif top_level_options.is_a?(Array) && top_level_options.any?
      top_level_options
    else
      default_options_for(field_type)
    end

    if (!options.is_a?(Array) || options.empty?) && (!top_level_options.is_a?(Array) || top_level_options.empty?)
      warnings << "Field '#{field["label"].presence || field_type}' (#{field_type}): options were missing, added placeholders"
    end

    sanitized_options = normalized_options.map { |option| option.to_s.strip }.reject(&:blank?)
    unique_options = sanitized_options.uniq

    if unique_options.empty?
      unique_options = default_options_for(field_type)
      warnings << "Field '#{field["label"].presence || field_type}' (#{field_type}): options were invalid, added placeholders"
    elsif unique_options.length != normalized_options.length
      warnings << "Field '#{field["label"].presence || field_type}' (#{field_type}): duplicate or blank options were removed"
    end

    metadata["options"] = unique_options

    allow_multiple = if metadata.key?("allow_multiple")
      metadata["allow_multiple"]
    elsif field.key?("allow_multiple")
      field["allow_multiple"]
    else
      false
    end

    if %w[checkbox buttons].include?(field_type)
      metadata["allow_multiple"] = ActiveModel::Type::Boolean.new.cast(allow_multiple)
    else
      metadata.delete("allow_multiple")
    end

    metadata
  end
  private_class_method :normalize_choice_metadata

  def self.normalize_table_metadata(label, metadata, field_type, warnings)
    return metadata.except("columns", "table") unless field_type == "table"

    columns = metadata["columns"]
    normalized_columns = if columns.is_a?(Array) && columns.any?
      columns.map.with_index(1) do |column, column_index|
        normalize_table_column(label, column, column_index, warnings)
      end
    else
      warnings << "Field '#{label.presence || "Table #{SecureRandom.hex(2)}"}' (table): columns were missing, added a placeholder column"
      [ default_table_column(1) ]
    end

    normalized_columns = ensure_unique_table_column_keys(label, normalized_columns, warnings)
    metadata["columns"] = normalized_columns

    if metadata["table"].is_a?(Hash)
      table_config = stringify_keys(metadata["table"])
      metadata["table"] = table_config.slice("min_rows", "max_rows", "default_row_count", "allow_add_rows").merge("columns" => normalized_columns)
    else
      metadata["table"] = { "columns" => normalized_columns }
    end

    metadata
  end
  private_class_method :normalize_table_metadata

  def self.normalize_file_metadata(label, index, metadata, field_type, warnings)
    return metadata.except("file") unless field_type == "file"

    file_metadata = metadata["file"]
    file_metadata = stringify_keys(file_metadata) if file_metadata.is_a?(Hash)

    unless file_metadata.nil? || file_metadata.is_a?(Hash)
      metadata.delete("file")
      warnings << "Field '#{label.presence || "Field #{index + 1}"}' had invalid file metadata and it was removed"
      return metadata
    end

    file_metadata ||= {}
    allowed_types = Array(file_metadata["allowed_types"]).map(&:to_s).select { |value| value.start_with?(".") }
    normalized = {}
    normalized["allowed_types"] = allowed_types if allowed_types.any?

    max_size_kb = Integer(file_metadata["max_size_kb"], exception: false)
    if max_size_kb&.positive?
      normalized["max_size_kb"] = max_size_kb
    elsif file_metadata["max_size_kb"].present?
      warnings << "Field '#{label.presence || "Field #{index + 1}"}' had invalid file size metadata and it was removed"
    end

    metadata["file"] = normalized if normalized.any?
    metadata.delete("file") if normalized.empty?
    metadata
  end
  private_class_method :normalize_file_metadata

  def self.normalize_layout_metadata(metadata, field_type)
    return metadata unless LAYOUT_FIELD_TYPES.include?(field_type)

    metadata = metadata.except("export_key", "crm_mapping")
    metadata
  end
  private_class_method :normalize_layout_metadata

  def self.duplicate_export_keys(fields)
    seen_by_scope = {}
    duplicates = []

    fields.each do |field|
      field_type = field["field_type"].to_s
      next if LAYOUT_FIELD_TYPES.include?(field_type)

      label = field["label"].to_s
      metadata = stringify_keys(field["metadata"] || {})
      export_key = metadata["export_key"].to_s.strip
      effective_key = export_key.presence || label
      normalized_key = normalize_export_key(effective_key)
      next if normalized_key.blank?

      scope = crm_scope_for(metadata)
      seen_by_scope[scope] ||= {}

      if seen_by_scope[scope].key?(normalized_key)
        duplicates << effective_key.to_s.strip
      else
        seen_by_scope[scope][normalized_key] = true
      end
    end

    duplicates.uniq
  end
  private_class_method :duplicate_export_keys

  def self.crm_scope_for(metadata)
    crm_mapping = metadata["crm_mapping"]
    return "contact" unless crm_mapping.is_a?(Hash)

    crm_mapping.values
               .filter_map { |mapping| mapping["object_type"].presence if mapping.is_a?(Hash) }
               .first || "contact"
  end
  private_class_method :crm_scope_for

  def self.normalize_export_key(value)
    value.to_s.parameterize(separator: "_").presence || value.to_s.strip.downcase.presence
  end
  private_class_method :normalize_export_key

  def self.normalize_table_column(label, column, index, warnings)
    unless column.is_a?(Hash)
      warnings << "Field '#{label.presence || "Table #{SecureRandom.hex(2)}"}' (table): column #{index} was invalid and replaced"
      return default_table_column(index)
    end

    payload = stringify_keys(column)
    column_type = payload["type"].to_s
    column_type = "text" unless TABLE_COLUMN_TYPES.include?(column_type)

    {
      "key" => payload["key"].presence || "col_#{index}",
      "label" => payload["label"].presence || "Column #{index}",
      "type" => column_type
    }
  end
  private_class_method :normalize_table_column

  def self.ensure_unique_table_column_keys(label, columns, warnings)
    seen_keys = {}

    columns.map.with_index(1) do |column, index|
      key = column["key"].to_s.presence || "col_#{index}"
      normalized_key = key.downcase

      if seen_keys.key?(normalized_key)
        replacement_key = next_available_table_column_key(index, seen_keys)
        warnings << "Field '#{label.presence || "Table #{SecureRandom.hex(2)}"}' (table): duplicate column key '#{key}' was replaced"
        column = column.merge("key" => replacement_key)
        normalized_key = replacement_key.downcase
      end

      seen_keys[normalized_key] = true
      column
    end
  end
  private_class_method :ensure_unique_table_column_keys

  def self.next_available_table_column_key(index, seen_keys)
    candidate_index = index

    loop do
      candidate_key = "col_#{candidate_index}"
      return candidate_key unless seen_keys.key?(candidate_key.downcase)

      candidate_index += 1
    end
  end
  private_class_method :next_available_table_column_key

  def self.default_options_for(field_type)
    field_type == "checkbox" ? [ "Option 1" ] : [ "Option 1", "Option 2" ]
  end
  private_class_method :default_options_for

  def self.default_table_column(index)
    {
      "key" => "col_#{index}",
      "label" => "Column #{index}",
      "type" => "text"
    }
  end
  private_class_method :default_table_column

  def self.normalize_settings(settings)
    payload = settings.is_a?(Hash) ? stringify_keys(settings) : {}
    DEFAULT_SETTINGS.merge(payload.slice(*DEFAULT_SETTINGS.keys))
  end
  private_class_method :normalize_settings

  def self.stringify_keys(value)
    case value
    when Array
      value.map { |item| stringify_keys(item) }
    when Hash
      value.each_with_object({}) do |(key, nested_value), memo|
        memo[key.to_s] = stringify_keys(nested_value)
      end
    else
      value
    end
  end
  private_class_method :stringify_keys

end
