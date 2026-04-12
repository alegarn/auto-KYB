class PdfImportExportKeyResolver

  LAYOUT_FIELD_TYPES = %w[section subtitle static_text separator logo].freeze

  Result = Struct.new(:fields, :warnings, keyword_init: true)

  def self.call(fields)
    resolved_fields = fields.deep_dup
    duplicate_groups = duplicate_groups_for(resolved_fields)

    return Result.new(fields: resolved_fields, warnings: []) if duplicate_groups.empty?

    context_candidates_by_index = context_candidates_for(resolved_fields)
    reserved_keys = reserved_keys_for(resolved_fields, duplicate_groups)
    warnings = []

    duplicate_groups.each_value do |entries|
      assigned_keys = assign_unique_keys(entries, context_candidates_by_index, reserved_keys)

      entries.each_with_index do |entry, index|
        entry[:field]["metadata"] ||= {}
        entry[:field]["metadata"]["export_key"] = assigned_keys[index]
      end

      warnings << "Generated unique export keys for duplicate field '#{entries.first[:display_key]}': #{assigned_keys.join(', ')}"
    end

    Result.new(fields: resolved_fields, warnings: warnings)
  end

  def self.duplicate_groups_for(fields)
    grouped_entries = Hash.new { |groups, key| groups[key] = [] }

    fields.each_with_index do |field, index|
      next if layout_field?(field)

      effective_key = effective_key_for(field)
      normalized_key = normalize_key(effective_key)
      next if normalized_key.blank?

      grouped_entries[normalized_key] << {
        field: field,
        index: index,
        display_key: effective_key.to_s.strip,
        base_key: export_key_base_for(field, index)
      }
    end

    grouped_entries.select { |_key, entries| entries.size > 1 }
  end
  private_class_method :duplicate_groups_for

  def self.context_candidates_for(fields)
    section_label = nil
    subtitle_label = nil

    fields.each_with_index.with_object({}) do |(field, index), memo|
      label = field["label"].to_s.strip.presence

      case field["field_type"].to_s
      when "section"
        section_label = label
        subtitle_label = nil
      when "subtitle"
        subtitle_label = label
      else
        memo[index] = suffix_candidates(section_label, subtitle_label)
      end
    end
  end
  private_class_method :context_candidates_for

  def self.suffix_candidates(section_label, subtitle_label)
    section_key = slugify(section_label)
    subtitle_key = slugify(subtitle_label)
    combined_key = [ section_key, subtitle_key ].compact.join("_").presence

    [ combined_key, subtitle_key, section_key ].compact.uniq
  end
  private_class_method :suffix_candidates

  def self.reserved_keys_for(fields, duplicate_groups)
    duplicate_keys = duplicate_groups.keys.index_with(true)

    fields.each_with_index.with_object({}) do |(field, index), memo|
      next if layout_field?(field)

      effective_key = effective_key_for(field)
      normalized_key = normalize_key(effective_key)
      next if normalized_key.blank?
      next if duplicate_keys.key?(normalized_key)

      memo[normalize_key(effective_key_for(field, fallback: "field_#{index + 1}"))] = true
    end
  end
  private_class_method :reserved_keys_for

  def self.assign_unique_keys(entries, context_candidates_by_index, reserved_keys)
    entries.map do |entry|
      base_key = entry[:base_key]
      contextual_roots = context_candidates_by_index.fetch(entry[:index], []).map { |suffix| "#{base_key}_#{suffix}" }
      preferred_root = contextual_roots.first || base_key

      selected_key = preferred_root unless reserved_keys.key?(normalize_key(preferred_root))
      selected_key ||= next_numeric_key(preferred_root, reserved_keys)

      reserved_keys[normalize_key(selected_key)] = true
      selected_key
    end
  end
  private_class_method :assign_unique_keys

  def self.next_numeric_key(root_key, reserved_keys)
    suffix = 2

    loop do
      candidate = "#{root_key}_#{suffix}"
      return candidate unless reserved_keys.key?(normalize_key(candidate))

      suffix += 1
    end
  end
  private_class_method :next_numeric_key

  def self.export_key_base_for(field, index)
    effective_key = effective_key_for(field, fallback: "field_#{index + 1}")
    slugify(effective_key).presence || "field_#{index + 1}"
  end
  private_class_method :export_key_base_for

  def self.effective_key_for(field, fallback: nil)
    metadata = field["metadata"] || {}
    export_key = metadata["export_key"].to_s.strip
    label = field["label"].to_s.strip

    export_key.presence || label.presence || fallback
  end
  private_class_method :effective_key_for

  def self.layout_field?(field)
    LAYOUT_FIELD_TYPES.include?(field["field_type"].to_s)
  end
  private_class_method :layout_field?

  def self.slugify(value)
    value.to_s.parameterize(separator: "_").presence
  end
  private_class_method :slugify

  def self.normalize_key(value)
    slugify(value) || value.to_s.strip.downcase.presence
  end
  private_class_method :normalize_key

end
