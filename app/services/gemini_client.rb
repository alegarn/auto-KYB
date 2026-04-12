require "json"
require "net/http"
require "openssl"
require "uri"

class GeminiClient

  class ApiError < StandardError; end

  API_BASE = "https://generativelanguage.googleapis.com/v1beta/models".freeze
  MODEL = "gemini-3.0-flash".freeze
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  def self.generate(system_prompt:, user_prompt:, pdf_file:)
    api_key = Rails.application.config.gemini.api_key
    raise ApiError, "Gemini API key not configured" if api_key.blank?

    uri = URI("#{API_BASE}/#{MODEL}:generateContent")
    request_body = {
      system_instruction: {
        parts: [ { text: system_prompt } ]
      },
      contents: [
        {
          parts: [
            { text: user_prompt },
            GeminiPdfInput.build(pdf_file)
          ]
        }
      ],
      generation_config: {
        temperature: 0.1,
        max_output_tokens: 8192
      }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = api_key
    request.body = JSON.generate(camelize_keys(request_body))

    response = http.request(request)
    raise ApiError, "Gemini API error (#{response.code}): #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

    extract_text(JSON.parse(response.body.to_s))
  rescue GeminiPdfInput::InvalidFileError => e
    raise ApiError, e.message
  rescue JSON::ParserError => e
    raise ApiError, "Malformed response from Gemini: #{e.message}"
  rescue Timeout::Error => e
    raise ApiError, "Gemini API timed out: #{e.message}"
  rescue IOError, SystemCallError, SocketError, Net::HTTPBadResponse, Net::ProtocolError,
         OpenSSL::SSL::SSLError => e
    raise ApiError, "Gemini API request failed: #{e.message}"
  end

  def self.camelize_keys(value)
    case value
    when Array
      value.map { |item| camelize_keys(item) }
    when Hash
      value.each_with_object({}) do |(key, nested_value), memo|
        memo[key.to_s.camelize(:lower)] = camelize_keys(nested_value)
      end
    else
      value
    end
  end
  private_class_method :camelize_keys

  def self.extract_text(parsed_body)
    unless parsed_body.is_a?(Hash)
      raise ApiError, "Malformed response from Gemini: unexpected response envelope"
    end

    candidates = parsed_body["candidates"]
    unless candidates.is_a?(Array)
      raise ApiError, "Malformed response from Gemini: missing candidates"
    end

    first_candidate = candidates.first
    unless first_candidate.is_a?(Hash)
      raise ApiError, "Malformed response from Gemini: invalid candidate payload"
    end

    content = first_candidate["content"]
    unless content.is_a?(Hash)
      raise ApiError, "Malformed response from Gemini: missing content payload"
    end

    parts = content["parts"]
    unless parts.is_a?(Array) && parts.all? { |part| part.is_a?(Hash) }
      raise ApiError, "Malformed response from Gemini: invalid content parts"
    end

    text = parts.filter_map { |part| part["text"].to_s.presence }.join("\n").presence
    raise ApiError, "Empty response from Gemini" if text.blank?

    text
  end
  private_class_method :extract_text

end
