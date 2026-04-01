class NormalizeCrmMappingCompoundKeys < ActiveRecord::Migration[8.1]
  def up
    FormField.where("metadata IS NOT NULL AND metadata::text LIKE ?", "%crm_mapping%").find_each do |field|
      metadata = field.metadata.deep_dup
      crm_mapping = metadata["crm_mapping"]
      next unless crm_mapping.is_a?(Hash)

      changed = false
      crm_mapping.each do |_provider, mapping|
        next unless mapping.is_a?(Hash)

        property_name = mapping["property_name"]
        object_type = mapping["object_type"]

        next if property_name.blank? || object_type.blank?
        next if property_name.include?(Crm::KeyParser::SEPARATOR) # already compound

        mapping["property_name"] = Crm::KeyParser.build(object_type, property_name)
        changed = true
      end

      field.update_column(:metadata, metadata) if changed
    end
  end

  def down
    FormField.where("metadata IS NOT NULL AND metadata::text LIKE ?", "%crm_mapping%").find_each do |field|
      metadata = field.metadata.deep_dup
      crm_mapping = metadata["crm_mapping"]
      next unless crm_mapping.is_a?(Hash)

      changed = false
      crm_mapping.each do |_provider, mapping|
        next unless mapping.is_a?(Hash)

        property_name = mapping["property_name"]
        next if property_name.blank?
        next unless property_name.include?(Crm::KeyParser::SEPARATOR)

        _object_type, clean_name = Crm::KeyParser.parse(property_name)
        mapping["property_name"] = clean_name
        changed = true
      end

      field.update_column(:metadata, metadata) if changed
    end
  end
end
