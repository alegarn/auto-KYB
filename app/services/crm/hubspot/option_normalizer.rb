require "set"

module Crm
  module Hubspot
    class OptionNormalizer

      # Generate a stable HubSpot internal value from a display label.
      # Rules: lowercase, alphanumeric + underscore only, no leading/trailing underscores,
      #        no consecutive underscores.
      def self.internal_value(label)
        label.to_s
             .strip
             .downcase
             .gsub(/[^a-z0-9]+/, "_")
             .gsub(/^_+|_+$/, "")
             .then { |s| s.empty? ? "option" : s }
      end

      # Build a full HubSpot options payload from an array of display labels.
      # Handles slug collisions by appending a numeric suffix.
      def self.build_options(labels)
        seen = Set.new
        labels.each_with_index.map do |label, i|
          base  = internal_value(label)
          value = base
          n     = 1
          while seen.include?(value)
            value = "#{base}_#{n}"
            n += 1
          end
          seen.add(value)
          { label: label.to_s, value: value, displayOrder: i }
        end
      end

    end
  end
end
