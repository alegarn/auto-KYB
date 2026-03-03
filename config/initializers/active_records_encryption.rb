Rails.application.config.active_record_encryption.tap do |c|
  c.primary_key         = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] ||
                          Rails.application.credentials.dig(:active_record_encryption, :primary_key)
  c.deterministic_key   = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] ||
                          Rails.application.credentials.dig(:active_record_encryption, :deterministic_key)
  c.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] ||
                          Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt)
end