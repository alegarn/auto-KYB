class FormService
  def self.initialize_default_for_user(user)
    Rails.logger.info("FormService: initializing default form for user=#{user.id}")
    return if user.forms.exists?(name: 'Default KYB Form')

    FormInitializer.default_for_user(user)
  rescue => e
    Rails.logger.error("FormService: failed to initialize default form for user=#{user.id} - #{e.message}")
    nil
  end

  def self.create_form(user, params)
    # Normalize structure to a plain Hash so we can access string or symbol keys
    struct = params[:structure].respond_to?(:to_h) ? params[:structure].to_h : (params[:structure] || {})
    form = user.forms.create!(name: params[:name], structure: struct)
    (struct['fields'] || struct[:fields] || []).each_with_index do |f, idx|
      label = f['label'] || f[:label]
      field_type = f['field_type'] || f[:field_type] || 'text'
      required = f.key?('required') ? f['required'] : (f.key?(:required) ? f[:required] : false)
      position = f['position'] || f[:position] || idx + 1
      metadata = f['metadata'] || f[:metadata] || {}
      form.form_fields.create!(label: label, field_type: field_type, required: required, position: position, metadata: metadata)
    end
    form
  end

  def self.update_form(user, form, params)
    raise ActiveRecord::RecordNotFound unless form.user_id == user.id
    ActiveRecord::Base.transaction do
      form.update!(name: params[:name]) if params.key?(:name)
      if params[:structure]
        # simplistic replacement strategy for now
        form.form_fields.destroy_all
        (params[:structure][:fields] || []).each_with_index do |f, idx|
          form.form_fields.create!(label: f[:label], field_type: f[:field_type], required: f[:required] || false, position: f[:position] || idx + 1, metadata: f[:metadata] || {})
        end
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
