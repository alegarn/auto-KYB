class PdfFormImportService

  Result = Struct.new(:success, :data, :warnings, :errors, keyword_init: true)

  def self.call(pdf_file)
    raw_response = GeminiClient.generate(
      system_prompt: PdfFormImportPrompt::SYSTEM_PROMPT,
      user_prompt: PdfFormImportPrompt.user_prompt,
      pdf_file: pdf_file
    )

    json_data = FormJsonExtractor.call(raw_response)
    normalize_form_data(json_data)
  end

  def self.normalize_form_data(form_data)
    sanitized_input = sanitize_value(form_data)
    validation = FormJsonValidator.call(sanitized_input)

    if validation.valid
      sanitized_data = sanitize_value(validation.data)
      sanitized_warnings = sanitize_value(validation.warnings)
      Result.new(success: true, data: sanitized_data, warnings: sanitized_warnings, errors: [])
    else
      Result.new(success: false, data: nil, warnings: [], errors: validation.errors)
    end
  end

  def self.sanitize_value(value)
    case value
    when Array
      value.map { |item| sanitize_value(item) }
    when Hash
      value.each_with_object({}) do |(key, nested_value), memo|
        memo[key] = sanitize_value(nested_value)
      end
    when String
      ActionController::Base.helpers.strip_tags(value).to_s.strip
    else
      value
    end
  end
  private_class_method :sanitize_value

end
