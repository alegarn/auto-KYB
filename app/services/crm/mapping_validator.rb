# frozen_string_literal: true

module Crm
  class MappingValidator

    SUPPORTED_PROVIDERS = %w[hubspot].freeze
    PROVIDER_LABELS = {
      "hubspot" => "HubSpot",
      "salesforce" => "Salesforce",
      "zoho" => "Zoho"
    }.freeze
    LAYOUT_FIELD_TYPES = %w[section subtitle static_text separator logo].freeze
    CHOICE_FIELD_TYPES = %w[select radio checkbox buttons].freeze

    class PropertyFetchError < StandardError; end

    Issue = Data.define(
      :provider,
      :field_key,
      :field_id,
      :index,
      :field_label,
      :object_type,
      :property_name,
      :code,
      :message,
      :invalid_options,
      :allowed_options
    )

    Result = Data.define(:issues, :messages) do
      def valid?
        issues.empty?
      end

      def as_json(*)
        {
          valid: valid?,
          issues: issues.map(&:to_h),
          messages: messages
        }
      end
    end

    def self.provider_label(provider)
      PROVIDER_LABELS[provider.to_s] || provider.to_s.titleize
    end

    def initialize(user:, fields:, provider_filter: nil)
      @user = user
      @fields = Array(fields).map { |field| stringify_keys(field) }
      @provider_filter = Array(provider_filter).filter_map do |provider|
        normalized = provider.to_s.strip
        normalized.presence
      end.presence
    end

    def call
      providers = providers_requiring_live_validation
      return Result.new(issues: [], messages: []) if providers.empty?

      live_properties = providers.index_with { |provider| fetch_live_properties(provider) }
      issues = validate_fields(live_properties)

      Result.new(
        issues: issues,
        messages: build_messages(issues)
      )
    end

    private

    attr_reader :user, :fields, :provider_filter

    def providers_requiring_live_validation
      providers = fields.flat_map do |field|
        next [] if layout_field?(field)

        crm_mapping_for(field).filter_map do |provider, mapping|
          provider_name = provider.to_s
          next unless supported_provider?(provider_name)
          next if provider_filter.present? && !provider_filter.include?(provider_name)
          next if mapping_type(mapping) == "custom"
          next if property_name_for(mapping).blank?
          next if Crm::ExportPayloadBuilder.pseudo_file_action?(property_name_for(mapping))

          provider_name
        end
      end

      providers.uniq.select { |provider| active_connections_by_provider.key?(provider) }
    end

    def validate_fields(live_properties)
      fields.each_with_index.flat_map do |field, index|
        next [] if layout_field?(field)

        crm_mapping_for(field).filter_map do |provider, mapping|
          provider_name = provider.to_s
          next unless supported_provider?(provider_name)
          next if provider_filter.present? && !provider_filter.include?(provider_name)
          next if mapping_type(mapping) == "custom"

          validate_mapping(field, index, provider_name, stringify_keys(mapping), live_properties[provider_name])
        end
      end
    end

    def validate_mapping(field, index, provider, mapping, provider_properties)
      return nil if provider_properties.blank?

      property_name = property_name_for(mapping)
      return nil if property_name.blank?
      return nil if Crm::ExportPayloadBuilder.pseudo_file_action?(property_name)

      object_type = object_type_for(mapping)
      property = provider_properties.dig(object_type, property_name)

      return build_missing_property_issue(field, index, provider, object_type, property_name) unless property
      return build_read_only_issue(field, index, provider, object_type, property_name) if property[:read_only]

      build_option_mismatch_issue(field, index, provider, object_type, property_name, property)
    end

    def build_missing_property_issue(field, index, provider, object_type, property_name)
      Issue.new(
        provider: provider,
        field_key: field_key_for(field, index),
        field_id: field["id"].presence,
        index: index,
        field_label: field_label_for(field, index),
        object_type: object_type,
        property_name: property_name,
        code: "missing_property",
        message: %(Live CRM check: #{self.class.provider_label(provider)} #{object_type} property "#{property_name}" no longer exists. Re-map this field or switch it to a custom property.),
        invalid_options: [],
        allowed_options: []
      )
    end

    def build_read_only_issue(field, index, provider, object_type, property_name)
      Issue.new(
        provider: provider,
        field_key: field_key_for(field, index),
        field_id: field["id"].presence,
        index: index,
        field_label: field_label_for(field, index),
        object_type: object_type,
        property_name: property_name,
        code: "read_only_property",
        message: %(Live CRM check: #{self.class.provider_label(provider)} #{object_type} property "#{property_name}" is read-only. Choose a writable property.),
        invalid_options: [],
        allowed_options: []
      )
    end

    def build_option_mismatch_issue(field, index, provider, object_type, property_name, property)
      return nil unless choice_field?(field)
      return nil unless property[:type] == "enumeration"

      crm_options = Array(property[:options])
      return nil if crm_options.empty?

      form_options = Array(field.dig("metadata", "options")).filter_map do |option|
        normalized = option.to_s.strip
        normalized.presence
      end
      return nil if form_options.empty?

      invalid_options = form_options.reject do |form_option|
        option_match?(form_option, crm_options)
      end
      return nil if invalid_options.empty?

      allowed_options = crm_options.filter_map do |option|
        value = option[:value].to_s.strip
        value.presence || option[:label].to_s.strip.presence
      end

      Issue.new(
        provider: provider,
        field_key: field_key_for(field, index),
        field_id: field["id"].presence,
        index: index,
        field_label: field_label_for(field, index),
        object_type: object_type,
        property_name: property_name,
        code: "option_mismatch",
        message: %(Live CRM check: "#{field_label_for(field, index)}" includes option#{"s" if invalid_options.size > 1} #{invalid_options.map { |value| %("#{value}") }.join(", ")} that #{invalid_options.size == 1 ? "is" : "are"} not valid for #{self.class.provider_label(provider)} #{object_type} property "#{property_name}". Allowed CRM values: #{allowed_options.join(", ")}.),
        invalid_options: invalid_options,
        allowed_options: allowed_options
      )
    end

    def option_match?(form_option, crm_options)
      normalized = form_option.to_s.strip.downcase

      crm_options.any? do |option|
        option[:label].to_s.strip.downcase == normalized || option[:value].to_s.strip.downcase == normalized
      end
    end

    def fetch_live_properties(provider)
      connection = active_connections_by_provider[provider]
      return nil unless connection

      service = Crm::ConnectionManager.service_for(connection)
      unless service.respond_to?(:fetch_properties)
        return nil
      end

      properties = normalize_provider_properties(service.fetch_properties(force: true))
      if properties.values.all?(&:empty?)
        raise PropertyFetchError, "#{provider}: live property inventory is unavailable"
      end

      properties
    rescue PropertyFetchError
      raise
    rescue StandardError => e
      raise PropertyFetchError, "#{provider}: #{e.message}"
    end

    def supported_provider?(provider)
      SUPPORTED_PROVIDERS.include?(provider)
    end

    def normalize_provider_properties(properties)
      %w[contact company].index_with do |object_type|
        Array(properties[object_type] || properties[object_type.to_sym]).each_with_object({}) do |property, memo|
          normalized = normalize_property(property)
          next if normalized[:name].blank?

          memo[normalized[:name]] = normalized
        end
      end
    end

    def normalize_property(property)
      hash = stringify_keys(property)

      {
        name: hash["name"].to_s.strip,
        type: hash["type"].to_s.downcase,
        field_type: hash["field_type"].to_s.downcase.presence,
        read_only: ActiveModel::Type::Boolean.new.cast(hash["read_only"]),
        options: Array(hash["options"]).map do |option|
          normalized = stringify_keys(option)
          {
            label: normalized["label"].to_s,
            value: normalized["value"].to_s
          }
        end
      }
    end

    def active_connections_by_provider
      @active_connections_by_provider ||= Crm::ConnectionManager.active_connections_for(user).index_by(&:provider)
    end

    def crm_mapping_for(field)
      mapping = field.dig("metadata", "crm_mapping")
      return {} unless mapping.is_a?(Hash)

      mapping.transform_values { |value| stringify_keys(value) }
    end

    def mapping_type(mapping)
      mapping["type"].to_s.presence || "existing"
    end

    def property_name_for(mapping)
      raw_property_name = mapping["property_name"].to_s.strip
      return "" if raw_property_name.blank?

      Crm::KeyParser.property_name(raw_property_name)
    end

    def object_type_for(mapping)
      raw_property_name = mapping["property_name"].to_s.strip
      if raw_property_name.present? && Crm::KeyParser.compound?(raw_property_name)
        Crm::KeyParser.object_type(raw_property_name)
      else
        mapping["object_type"].to_s.presence || "contact"
      end
    end

    def field_key_for(field, index)
      field_id = field["id"]
      return "id:#{field_id}" if field_id.present?

      "draft:#{index}"
    end

    def field_label_for(field, index)
      field["label"].to_s.presence || "Field #{index + 1}"
    end

    def layout_field?(field)
      LAYOUT_FIELD_TYPES.include?(field["field_type"].to_s)
    end

    def choice_field?(field)
      CHOICE_FIELD_TYPES.include?(field["field_type"].to_s)
    end

    def build_messages(issues)
      issues.group_by(&:provider).map do |provider, provider_issues|
        count = provider_issues.size
        %(#{self.class.provider_label(provider)} live verification found #{count} blocking issue#{"s" if count != 1}. Fix #{count == 1 ? "it" : "them"} before saving or sending test data.)
      end
    end

    def stringify_keys(value)
      case value
      when Array
        value.map { |item| stringify_keys(item) }
      when Hash
        value.each_with_object({}) do |(key, nested_value), memo|
          memo[key.to_s] = stringify_keys(nested_value)
        end
      else
        value.respond_to?(:to_h) && !value.is_a?(Struct) ? stringify_keys(value.to_h) : value
      end
    end

  end
end
