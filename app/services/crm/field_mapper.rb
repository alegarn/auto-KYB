# frozen_string_literal: true

module Crm
  class FieldMapper

    # This class serves as a placeholder for shared CRM mapping logic.
    # Specific CRM mappers should be located in Crm::[Provider]::FieldMapper.

    # Example shared utility: splitting names
    def self.split_name(name)
      return [ nil, nil ] if name.blank?
      parts = name.split(" ", 2)
      [ parts[0], parts[1] || "" ]
    end

  end
end
