class FileValidationService

  ALLOWED_CONTENT_TYPES = FileUploadConstraints.allowed_content_types
  MAX_FILE_SIZE = FileUploadConstraints.max_file_size_bytes

  MAGIC_BYTES = FileUploadConstraints::MAGIC_BYTES_BY_CONTENT_TYPE

  Result = Struct.new(:valid, :error, keyword_init: true) do
    def valid? = valid
  end

  def self.validate(file)
    new(file).validate
  end

  def initialize(file)
    @file = file
  end

  def validate
    return Result.new(valid: false, error: "No file provided") unless @file

    check_size || check_content_type || check_magic_bytes || Result.new(valid: true)
  end

  private

  def check_size
    size = @file.respond_to?(:size) ? @file.size : @file.tempfile&.size
    return nil unless size && size > MAX_FILE_SIZE

    max_mb = MAX_FILE_SIZE / 1.megabyte
    Result.new(valid: false, error: "File exceeds maximum size of #{max_mb}MB")
  end

  def check_content_type
    detected_type = detect_content_type
    return nil if ALLOWED_CONTENT_TYPES.include?(detected_type)

    Result.new(
      valid: false,
      error: "File type '#{detected_type}' is not supported. Allowed: #{FileUploadConstraints.allowed_types_human}"
    )
  end

  def check_magic_bytes
    header = read_header(8)
    return nil unless header

    detected_type = detect_content_type
    signatures = MAGIC_BYTES[detected_type]
    return nil unless signatures

    match = signatures.any? { |sig| header.start_with?(sig) }
    return nil if match

    Result.new(
      valid: false,
      error: "File content does not match its declared type"
    )
  end

  def detect_content_type
    if @file.respond_to?(:content_type)
      @file.content_type
    elsif defined?(Marcel) && @file.respond_to?(:tempfile)
      Marcel::MimeType.for(@file.tempfile, name: @file.original_filename)
    else
      "application/octet-stream"
    end
  end

  def read_header(bytes)
    io = if @file.respond_to?(:tempfile)
           @file.tempfile
         elsif @file.respond_to?(:read)
           @file
         end

    return nil unless io

    io.rewind if io.respond_to?(:rewind)
    data = io.read(bytes)
    io.rewind if io.respond_to?(:rewind)
    data
  end

end
