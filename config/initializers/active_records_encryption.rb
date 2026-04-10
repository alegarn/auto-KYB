Rails.application.config.active_record.encryption.tap do |c|
  c.primary_key         = Rails.application.credentials.dig(:active_record_encryption, :primary_key) ||
                          ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
  c.deterministic_key   = Rails.application.credentials.dig(:active_record_encryption, :deterministic_key) ||
                          ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
  c.key_derivation_salt = Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt) ||
                          ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
end
