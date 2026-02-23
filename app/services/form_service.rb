class FormService

  class DataLossWarning < StandardError; end

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

    base_name = form.name.sub(/\s*\(\d+\)$/, '').strip
    
    existing_names = user.forms.where("name LIKE ?", "#{base_name}%").pluck(:name)
    
    new_name = "#{base_name} (1)"
    counter = 1
    while existing_names.include?(new_name)
      counter += 1
      new_name = "#{base_name} (#{counter})"
    end

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

end
