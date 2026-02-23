class FileUploadConstraints

  ALLOWED_CONTENT_TYPES = UploadedFile::ALLOWED_CONTENT_TYPES.freeze
  MAX_FILE_SIZE_BYTES = UploadedFile::MAX_FILE_SIZE

  DISPLAY_LABELS_BY_CONTENT_TYPE = {
    "application/pdf" => "PDF",
    "image/jpeg" => "JPEG",
    "image/png" => "PNG"
  }.freeze

  EXTENSIONS_BY_CONTENT_TYPE = {
    "application/pdf" => %w[pdf],
    "image/jpeg" => %w[jpg jpeg],
    "image/png" => %w[png]
  }.freeze

  MAGIC_BYTES_BY_CONTENT_TYPE = {
    "application/pdf" => [ "%PDF" ],
    "image/jpeg" => [ "\xFF\xD8\xFF".b ],
    "image/png" => [ "\x89PNG".b ]
  }.freeze

  def self.allowed_content_types
    ALLOWED_CONTENT_TYPES
  end

  def self.max_file_size_bytes
    MAX_FILE_SIZE_BYTES
  end

  def self.allowed_extensions
    ALLOWED_CONTENT_TYPES.flat_map { |mime| EXTENSIONS_BY_CONTENT_TYPE[mime] || [] }.uniq
  end

  def self.allowed_type_labels
    ALLOWED_CONTENT_TYPES.map { |mime| DISPLAY_LABELS_BY_CONTENT_TYPE[mime] || mime }
  end

  def self.default_accept
    allowed_extensions.map { |ext| ".#{ext}" }.join(",")
  end

  def self.allowed_types_human
    allowed_type_labels.join(", ")
  end

  def self.as_json(*_args)
    {
      allowed_content_types: allowed_content_types,
      allowed_extensions: allowed_extensions,
      allowed_type_labels: allowed_type_labels,
      max_file_size_bytes: max_file_size_bytes,
      default_accept: default_accept
    }
  end

end
