class FormService

  class DataLossWarning < StandardError; end
  class DuplicateExportKeysError < StandardError

    attr_reader :duplicate_keys

    def initialize(duplicate_keys)
      @duplicate_keys = duplicate_keys
      super("Export mapping keys must be unique")
    end

  end

  def self.initialize_default_for_user(user)
    Rails.logger.info("FormService: initializing default form for user=#{user.id}")
    return if user.forms.exists?(name: "Default KYB Form")

    FormInitializer.default_for_user(user)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("FormService: failed to initialize default form for user=#{user.id} - #{e.message}")
    nil
  end

  def self.create_form(user, params)
    # Normalize structure to a plain Hash so we can access string or symbol keys
    struct = params[:structure].respond_to?(:to_h) ? params[:structure].to_h : (params[:structure] || {})
    validate_unique_export_keys!(struct)
    ActiveRecord::Base.transaction do
      form = user.forms.create!(name: params[:name], structure: struct)
      (struct["fields"] || struct[:fields] || []).each_with_index do |f, idx|
        label = f["label"] || f[:label]
        field_type = f["field_type"] || f[:field_type] || "text"
        required = f.key?("required") ? f["required"] : (f.key?(:required) ? f[:required] : false)
        position = f["position"] || f[:position] || idx + 1
        metadata = f["metadata"] || f[:metadata] || {}
        form.form_fields.create!(label: label, field_type: field_type, required: required, position: position, metadata: metadata)
      end
      form
    end
  end

  def self.update_form(user, form, params)
    raise ActiveRecord::RecordNotFound unless form.user_id == user.id

    if params[:structure]
      incoming_fields = params[:structure][:fields] || params[:structure]["fields"] || []
      incoming_ids = incoming_fields.filter_map { |f| (f["id"] || f[:id]).to_s }.reject(&:blank?)
      existing_ids = form.form_fields.pluck(:id).map(&:to_s)
      removed_ids = existing_ids - incoming_ids

      removed_ids.each do |field_id|
        field = form.form_fields.find_by(id: field_id)
        if field && Form.respond_to?(:has_submissions_for_field?) && Form.has_submissions_for_field?(form.id, field.label)
          raise DataLossWarning, "Update would remove field '#{field.label}' which has submissions"
        end
      end
    end

    validate_unique_export_keys!(params[:structure]) if params[:structure]

    ActiveRecord::Base.transaction do
      form.update!(name: params[:name]) if params.key?(:name)
      if params[:structure]
        new_fields = (params[:structure][:fields] || params[:structure]["fields"] || []).map.with_index(1) do |f, idx|
          {
            id: (f["id"] || f[:id]).to_s.presence,
            label: f["label"] || f[:label],
            field_type: f["field_type"] || f[:field_type],
            required: f.key?("required") ? f["required"] : (f.key?(:required) ? f[:required] : false),
            position: f["position"] || f[:position] || idx,
            metadata: f["metadata"] || f[:metadata] || {}
          }
        end

        existing = form.form_fields.index_by { |ff| ff.id.to_s }
        seen_ids = []

        new_fields.each do |nf|
          field_id = nf[:id]
          if field_id && (existing_field = existing[field_id])
            existing_field.update!(
              label: nf[:label],
              field_type: nf[:field_type],
              required: nf[:required],
              position: nf[:position],
              metadata: nf[:metadata]
            )
            seen_ids << field_id
          else
            created = form.form_fields.create!(
              label: nf[:label],
              field_type: nf[:field_type],
              required: nf[:required],
              position: nf[:position],
              metadata: nf[:metadata]
            )
            seen_ids << created.id.to_s
          end
        end

        to_remove = existing.keys - seen_ids
        form.form_fields.where(id: to_remove).destroy_all if to_remove.any?

        form.update!(structure: params[:structure])
      end
    end
    form
  end

  def self.delete_form(user, form)
    raise ActiveRecord::RecordNotFound unless form.user_id == user.id
    form.destroy!
  end

  def self.duplicate_form(user, form)
    raise ActiveRecord::RecordNotFound unless form.user_id == user.id

    base_name = duplicate_base_name(form.name)
    new_name = next_duplicate_name_for_user(user, base_name)

    new_structure = form.structure.deep_dup || {}
    new_structure["fields"] = form.form_fields.order(:position).map do |ff|
      {
        "label" => ff.label,
        "field_type" => ff.field_type,
        "required" => ff.required,
        "position" => ff.position,
        "metadata" => ff.metadata || {}
      }
    end

    create_form(user, { name: new_name, structure: new_structure })
  end

  def self.duplicate_base_name(name)
    name.to_s.sub(/\s*\(\d+\)\z/, "").strip
  end
  private_class_method :duplicate_base_name

  def self.next_duplicate_name_for_user(user, base_name)
    escaped_base = Regexp.escape(base_name)
    duplicate_regex = /\A#{escaped_base} \((\d+)\)\z/

    existing_names = user.forms
                         .where("name = ? OR name LIKE ?", base_name, "#{base_name} (%)")
                         .pluck(:name)

    max_suffix = existing_names.filter_map { |name| duplicate_regex.match(name)&.captures&.first&.to_i }.max || 0
    "#{base_name} (#{max_suffix + 1})"
  end
  private_class_method :next_duplicate_name_for_user

  def self.validate_unique_export_keys!(structure)
    return unless structure

    fields = structure[:fields] || structure["fields"] || []
    return if fields.blank?

    layout_types = %w[section subtitle static_text separator logo]
    seen_by_scope = {}
    duplicates = []

    fields.each do |field|
      field_type = field[:field_type] || field["field_type"]
      next if layout_types.include?(field_type.to_s)

      label = (field[:label] || field["label"]).to_s
      metadata = field[:metadata] || field["metadata"] || {}
      export_key = metadata[:export_key] || metadata["export_key"]
      effective_key = export_key.to_s.presence || label

      normalized = effective_key.to_s.strip.downcase
      next if normalized.blank?

      # Scope uniqueness by CRM object_type — same key is allowed across different objects
      crm_mapping = metadata[:crm_mapping] || metadata["crm_mapping"] || {}
      object_type = crm_mapping.values
                      .filter_map { |m| m["object_type"] || m[:object_type] }
                      .first || "contact"

      seen_by_scope[object_type] ||= {}
      if seen_by_scope[object_type].key?(normalized)
        duplicates << effective_key.to_s.strip
      else
        seen_by_scope[object_type][normalized] = true
      end
    end

    raise DuplicateExportKeysError.new(duplicates.uniq) if duplicates.any?
  end
  private_class_method :validate_unique_export_keys!

end
