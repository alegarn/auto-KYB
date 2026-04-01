module Crm
  # Compound-key helpers for CRM property disambiguation.
  #
  # A compound key encodes both the CRM object type and the raw property name
  # into a single string: "company::address", "contact::email", etc.
  #
  # This ensures that even if the separate `object_type` field is lost or
  # corrupted, the system can still route data to the correct CRM object.
  module KeyParser
    SEPARATOR = "::"

    # Parse a (possibly compound) key into [object_type, clean_property_name].
    # Legacy keys without a separator default to "contact".
    def self.parse(raw_key)
      key = raw_key.to_s
      return [ "contact", key ] unless key.include?(SEPARATOR)

      object_type, property_name = key.split(SEPARATOR, 2)
      [ object_type, property_name ]
    end

    # Build a compound key from object_type and a raw CRM property name.
    def self.build(object_type, property_name)
      "#{object_type}#{SEPARATOR}#{property_name}"
    end

    # Extract just the clean property name (strip the prefix).
    def self.property_name(raw_key)
      parse(raw_key).last
    end

    # Extract just the object type from a (possibly compound) key.
    def self.object_type(raw_key)
      parse(raw_key).first
    end

    # Is this already a compound key?
    def self.compound?(raw_key)
      raw_key.to_s.include?(SEPARATOR)
    end
  end
end
