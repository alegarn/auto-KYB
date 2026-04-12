require "json"

class FormJsonExtractor

  class ExtractionError < StandardError; end

  def self.call(raw_text)
    candidates = [
      raw_text.to_s,
      strip_code_fences(raw_text.to_s),
      extract_json_object(raw_text.to_s)
    ].compact.uniq

    candidates.each do |candidate|
      begin
        return safe_parse(candidate)
      rescue ExtractionError
        next
      end
    end

    raise ExtractionError, "Could not extract valid JSON from the LLM response"
  end

  def self.strip_code_fences(text)
    text.gsub(/\A\s*```(?:json)?\s*/i, "").gsub(/\s*```\s*\z/, "").strip
  end
  private_class_method :strip_code_fences

  def self.extract_json_object(text)
    start_index = text.index("{")
    return nil unless start_index

    depth = 0
    in_string = false
    escape_next = false

    (start_index...text.length).each do |index|
      char = text[index]

      if escape_next
        escape_next = false
        next
      end

      if in_string && char == "\\"
        escape_next = true
        next
      end

      if char == '"'
        in_string = !in_string
        next
      end

      next if in_string

      depth += 1 if char == "{"
      depth -= 1 if char == "}"

      return text[start_index..index] if depth.zero?
    end

    nil
  end
  private_class_method :extract_json_object

  def self.safe_parse(text)
    parsed = JSON.parse(text)
    raise ExtractionError, "Expected a JSON object" unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError => e
    raise ExtractionError, e.message
  end
  private_class_method :safe_parse

end
