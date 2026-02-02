class FormService
  def self.initialize_default_for_user(user)
    return if user.forms.exists?(name: 'Default KYB Form')

    FormInitializer.default_for_user(user)
  rescue => e
    Rails.logger.error("FormService: failed to initialize default form for user=#{user.id} - "+e.message)
    raise
  end

  def self.create_form(user, params)
    form = user.forms.create!(name: params[:name], structure: params[:structure] || {})
    (params[:structure] || { fields: [] })[:fields].each_with_index do |f, idx|
      form.form_fields.create!(label: f[:label], field_type: f[:field_type], required: f[:required] || false, position: f[:position] || idx + 1, metadata: f[:metadata] || {})
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
