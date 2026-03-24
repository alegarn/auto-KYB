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
      def coerce(value, property_type)
        return value.to_s if value.nil? || property_type.nil?

        case property_type.to_s
        when "date", "datetime"
          coerce_date(value)
        when "number"
          coerce_number(value)
        when "bool"
          coerce_bool(value)
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

      private_class_method :parse_date
    end
  end
end
