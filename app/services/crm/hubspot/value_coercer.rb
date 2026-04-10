# frozen_string_literal: true

module Crm
  module Hubspot
    # Coerces Ruby values to the format expected by HubSpot property types.
    #
    # HubSpot date/datetime properties expect Unix millisecond timestamps,
    # number properties expect numeric strings, etc.  Without coercion the
    # API rejects raw form values like "2026-03-24" for a datetime field.
    module ValueCoercer
      module_function

      # Coerce +value+ according to the HubSpot +property_type+.
      # Returns a String suitable for the HubSpot v1/v3 property APIs.
      def coerce(value, property_type, property_metadata: {})
        return value.to_s if value.nil? || property_type.nil?

        case property_type.to_s
        when "date", "datetime"
          coerce_date(value)
        when "number"
          coerce_number(value)
        when "bool"
          coerce_bool(value)
        when "enumeration"
          coerce_enumeration(value, property_metadata)
        else
          value.to_s
        end
      end

      # HubSpot dates are stored as Unix‑millisecond timestamps at midnight UTC.
      def coerce_date(value)
        return value.to_s if value.to_s.match?(/\A-?\d{10,16}\z/) # already a timestamp

        parsed = parse_date(value)
        return value.to_s unless parsed

        (parsed.in_time_zone("UTC").beginning_of_day.to_i * 1000).to_s
      end

      def coerce_number(value)
        cleaned = value.to_s.strip
        return cleaned if cleaned.match?(/\A-?\d+(\.\d+)?\z/)

        # Strip non-numeric chars (currency symbols, spaces, commas)
        cleaned.gsub(/[^\d.\-]/, "")
      end

      def coerce_bool(value)
        case value.to_s.strip.downcase
        when "true", "1", "yes", "on" then "true"
        when "false", "0", "no", "off", "" then "false"
        else value.to_s
        end
      end

      def parse_date(value)
        case value
        when Date, Time, DateTime then value.to_date
        else Date.parse(value.to_s)
        end
      rescue Date::Error, ArgumentError
        nil
      end

      def coerce_enumeration(value, metadata)
        options    = metadata[:options] || []
        field_type = metadata[:field_type]

        # booleancheckbox: an enumeration whose only valid API values are "true"/"false"
        return coerce_bool(value) if field_type == "booleancheckbox"

        if field_type == "checkbox"
          values = normalize_to_array(value)
          resolved = values.map { |v| resolve_option(v, options) }.reject { |r| r.to_s.empty? }
          resolved.join(";")
        else
          resolve_option(value, options)
        end
      end

      # Resolve a single form value to a HubSpot internal option value.
      # Priority: 1) exact label match (case-insensitive)
      #           2) direct internal value match
      #           3) pass through as-is
      def resolve_option(form_value, options)
        return form_value.to_s if options.empty?

        normalized = form_value.to_s.strip.downcase

        # 1. Case-insensitive label match
        match = options.find { |o| o[:label].to_s.downcase == normalized }
        return match[:value].to_s if match

        # 2. Direct internal value match
        value_match = options.find { |o| o[:value].to_s.downcase == normalized }
        return value_match[:value].to_s if value_match

        # 3. No match — pass through (HubSpot will reject with a clear error)
        form_value.to_s
      end

      def normalize_to_array(value)
        case value
        when Array
          value.map(&:to_s).reject(&:empty?)
        when String
          value.split(/[;,]/).map(&:strip).reject(&:empty?)
        else
          [ value.to_s ].reject(&:empty?)
        end
      end

      private_class_method :parse_date
    end
  end
end
