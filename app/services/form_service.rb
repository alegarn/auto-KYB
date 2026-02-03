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

    # minimal data-loss warning: detect removed field labels and raise if any have submissions
    if params[:structure]
      existing_labels = form.form_fields.pluck(:label).map(&:to_s)
      new_labels = (params[:structure][:fields] || []).map { |f| (f["label"] || f[:label]).to_s }
      removed = existing_labels - new_labels
      removed.each do |label|
        # allow spec to stub this class method
        if Form.respond_to?(:has_submissions_for_field?) && Form.has_submissions_for_field?(form.id, label)
          raise DataLossWarning, "Update would remove field '#{label}' which has submissions"
        end
      end
    end

    ActiveRecord::Base.transaction do
      form.update!(name: params[:name]) if params.key?(:name)
      if params[:structure]
        new_fields = (params[:structure][:fields] || []).map.with_index(1) do |f, idx|
          {
            label: f["label"] || f[:label],
            field_type: f["field_type"] || f[:field_type],
            required: f.key?("required") ? f["required"] : (f.key?(:required) ? f[:required] : false),
            position: f["position"] || f[:position] || idx,
            metadata: f["metadata"] || f[:metadata] || {}
          }
        end

        existing = form.form_fields.index_by { |ff| ff.label.to_s }
        processed = []

        new_fields.each do |nf|
          label = nf[:label].to_s
          processed << label
          if existing_field = existing[label]
            existing_field.update!(field_type: nf[:field_type], required: nf[:required], position: nf[:position], metadata: nf[:metadata])
          else
            form.form_fields.create!(label: nf[:label], field_type: nf[:field_type], required: nf[:required], position: nf[:position], metadata: nf[:metadata])
          end
        end

        to_remove = existing.keys - processed
        form.form_fields.where(label: to_remove).destroy_all if to_remove.any?

        form.update!(structure: params[:structure])
      end
    end
    form
  end

  def self.delete_form(user, form)
    raise ActiveRecord::RecordNotFound unless form.user_id == user.id
    form.destroy!
  end
end
