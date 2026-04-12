class GeminiPdfInput

  class InvalidFileError < StandardError; end

  def self.build(pdf_file)
    raise InvalidFileError, "PDF file is required" if pdf_file.nil?

    pdf_bytes = read_bytes(pdf_file)
    raise InvalidFileError, "PDF file is empty" if pdf_bytes.blank?

    {
      inline_data: {
        mime_type: "application/pdf",
        data: Base64.strict_encode64(pdf_bytes)
      }
    }
  end

  def self.read_bytes(pdf_file)
    if pdf_file.respond_to?(:read)
      pdf_bytes = pdf_file.read
      pdf_file.rewind if pdf_file.respond_to?(:rewind)
      pdf_bytes
    else
      pdf_file.to_s
    end
  end
  private_class_method :read_bytes

end
