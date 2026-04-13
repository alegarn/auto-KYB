class PdfImportUploadValidator

  MAX_FILE_SIZE = 10.megabytes
  PDF_SIGNATURE_BYTES = 5
  PDF_SIGNATURE_PREFIX = "%PDF-".freeze

  Result = Struct.new(:valid, :error, keyword_init: true) do
    def valid?
      valid
    end
  end

  def self.validate(pdf_file)
    new(pdf_file).validate
  end

  def initialize(pdf_file)
    @pdf_file = pdf_file
  end

  def validate
    return invalid("Only PDF files are accepted") unless upload_like_file?
    return invalid("File too large (max 10 MB)") if @pdf_file.size > MAX_FILE_SIZE
    return invalid("Only PDF files are accepted") unless pdf_signature?

    Result.new(valid: true, error: nil)
  end

  private

  def invalid(message)
    Result.new(valid: false, error: message)
  end

  def upload_like_file?
    @pdf_file.respond_to?(:size) && @pdf_file.respond_to?(:read) && @pdf_file.respond_to?(:rewind)
  end

  def pdf_signature?
    signature = @pdf_file.read(PDF_SIGNATURE_BYTES)
    @pdf_file.rewind
    signature&.start_with?(PDF_SIGNATURE_PREFIX)
  end

end
