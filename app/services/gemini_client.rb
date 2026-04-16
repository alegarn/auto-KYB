require "json"
require "net/http"
require "openssl"
require "uri"

class GeminiClient

  class ApiError < StandardError

    attr_reader :retry_count

    def initialize(message = nil, retry_count: 0)
      super(message)
      @retry_count = retry_count
    end

  end

  API_BASE = "https://generativelanguage.googleapis.com/v1beta/models".freeze
  MODEL_CHAIN = [
    "gemini-3.1-flash-lite-preview",
    "gemini-3-flash-preview",
    "gemini-3.1-pro-preview"
  ].freeze
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  def self.generate(system_prompt:, user_prompt:, pdf_file:)
    MODEL_CHAIN.each_with_index do |model, index|
      begin
        return generate_with_model(
          model: model,
          system_prompt: system_prompt,
          user_prompt: user_prompt,
          pdf_file: pdf_file
        )
      rescue ApiError => e
        enhanced_error = ApiError.new(e.message, retry_count: index)

        raise enhanced_error unless retryable_model_error?(e)

        fallback_model = MODEL_CHAIN[index + 1]
        raise enhanced_error unless fallback_model

        Rails.logger.warn("[GeminiClient] #{model} failed with #{e.message}; retrying with #{fallback_model}")
      end
    end

    raise ApiError.new("Gemini API request failed")
  end

  def self.generate_text(system_prompt:, user_prompt:, model: MODEL_CHAIN.first)
    request_body = {
      system_instruction: {
        parts: [ { text: system_prompt } ]
      },
      contents: [
        {
          parts: [
            { text: user_prompt }
          ]
        }
      ],
      generation_config: {
        temperature: 0.1,
        max_output_tokens: 8192
      }
    }

    perform_request(model: model, request_body: request_body)
  end

  def self.generate_with_model(model:, system_prompt:, user_prompt:, pdf_file:)
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

    perform_request(model: model, request_body: request_body)
  rescue GeminiPdfInput::InvalidFileError => e
    raise ApiError, e.message
  end

  def self.perform_request(model:, request_body:)
    api_key = Rails.application.config.gemini.api_key
    raise ApiError, "Gemini API key not configured" if api_key.blank?

    uri = URI("#{API_BASE}/#{model}:generateContent")

    with_network_rescue do
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
    end
  end

  def self.with_network_rescue
    yield
  rescue JSON::ParserError => e
    raise ApiError, "Malformed response from Gemini: #{e.message}"
  rescue Timeout::Error => e
    raise ApiError, "Gemini API timed out: #{e.message}"
  rescue IOError, SystemCallError, SocketError, Net::HTTPBadResponse, Net::ProtocolError,
         OpenSSL::SSL::SSLError => e
    raise ApiError, "Gemini API request failed: #{e.message}"
  end

  def self.retryable_model_error?(error)
    message = error.message.to_s

    message.match?(/Gemini API error \((429|502|503|504)\)/)
  end
  private_class_method :retryable_model_error?

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
