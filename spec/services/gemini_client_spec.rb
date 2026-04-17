require 'rails_helper'
require 'stringio'

RSpec.describe GeminiClient do
  let(:pdf_file) { StringIO.new("%PDF-1.4\nhello") }
  let(:base_endpoint) { 'https://generativelanguage.googleapis.com/v1beta/models' }

  def endpoint_for(model)
    "#{base_endpoint}/#{model}:generateContent"
  end

  def overload_body
    {
      error: {
        code: 503,
        message: 'This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.',
        status: 'UNAVAILABLE'
      }
    }.to_json
  end

  around do |example|
    original_key = Rails.application.config.gemini.api_key
    Rails.application.config.gemini.api_key = 'test-gemini-key'
    example.run
  ensure
    Rails.application.config.gemini.api_key = original_key
  end

  it 'returns text from a successful API response' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(
        status: 200,
        body: {
          candidates: [
            {
              content: {
                parts: [
                  { text: '{"name":"Imported Form"}' }
                ]
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)

    expect(result).to eq('{"name":"Imported Form"}')
  end

  it 'returns text from a successful text-only API response' do
    captured_body = nil

    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .with do |request|
        captured_body = JSON.parse(request.body)
        true
      end
      .to_return(
        status: 200,
        body: {
          candidates: [
            {
              content: {
                parts: [
                  { text: '{"field":"email"}' }
                ]
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.generate_text(system_prompt: 'system', user_prompt: 'user')

    expect(result).to eq('{"field":"email"}')
    expect(captured_body.dig('contents', 0, 'parts')).to eq([ { 'text' => 'user' } ])
  end

  it 'falls back from flash-lite to flash-preview when the first model is overloaded' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(status: 503, body: overload_body, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, endpoint_for('gemini-3-flash-preview'))
      .to_return(
        status: 200,
        body: {
          candidates: [
            {
              content: {
                parts: [
                  { text: '{"name":"Imported Form"}' }
                ]
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)

    expect(result).to eq('{"name":"Imported Form"}')
    expect(a_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))).to have_been_made.once
    expect(a_request(:post, endpoint_for('gemini-3-flash-preview'))).to have_been_made.once
  end

  it 'falls back from flash-lite to flash-preview for text-only requests when the first model is overloaded' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(status: 503, body: overload_body, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, endpoint_for('gemini-3-flash-preview'))
      .to_return(
        status: 200,
        body: {
          candidates: [
            {
              content: {
                parts: [
                  { text: '{"field":"email"}' }
                ]
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.generate_text(system_prompt: 'system', user_prompt: 'user')

    expect(result).to eq('{"field":"email"}')
    expect(a_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))).to have_been_made.once
    expect(a_request(:post, endpoint_for('gemini-3-flash-preview'))).to have_been_made.once
  end

  it 'falls back to pro when both flash models are overloaded' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(status: 503, body: overload_body, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, endpoint_for('gemini-3-flash-preview'))
      .to_return(status: 503, body: overload_body, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, endpoint_for('gemini-3.1-pro-preview'))
      .to_return(
        status: 200,
        body: {
          candidates: [
            {
              content: {
                parts: [
                  { text: '{"name":"Imported Form"}' }
                ]
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)

    expect(result).to eq('{"name":"Imported Form"}')
    expect(a_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))).to have_been_made.once
    expect(a_request(:post, endpoint_for('gemini-3-flash-preview'))).to have_been_made.once
    expect(a_request(:post, endpoint_for('gemini-3.1-pro-preview'))).to have_been_made.once
  end

  it 'records the number of retries when all fallback models fail' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(status: 503, body: overload_body, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, endpoint_for('gemini-3-flash-preview'))
      .to_return(status: 503, body: overload_body, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, endpoint_for('gemini-3.1-pro-preview'))
      .to_return(
        status: 429,
        body: {
          error: {
            code: 429,
            message: 'You exceeded your current quota, please check your plan and billing details.',
            status: 'RESOURCE_EXHAUSTED'
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError) { |error|
      expect(error.retry_count).to eq(2)
      expect(error.message).to match(/Gemini API error \(429\)/)
    }

    expect(a_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))).to have_been_made.once
    expect(a_request(:post, endpoint_for('gemini-3-flash-preview'))).to have_been_made.once
    expect(a_request(:post, endpoint_for('gemini-3.1-pro-preview'))).to have_been_made.once
  end

  it 'raises ApiError on HTTP error responses' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview')).to_return(status: 500, body: 'upstream failure')

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /Gemini API error \(500\)/)
  end

  it 'raises ApiError when the API key is missing' do
    Rails.application.config.gemini.api_key = nil

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, 'Gemini API key not configured')
  end

  it 'raises ApiError on empty response text' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(
        status: 200,
        body: { candidates: [ { content: { parts: [ {} ] } } ] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, 'Empty response from Gemini')
  end

  it 'sends the PDF as inline data with the PDF mime type' do
    captured_body = nil

    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .with do |request|
        captured_body = JSON.parse(request.body)
        request.headers['X-Goog-Api-Key'] == 'test-gemini-key'
      end
      .to_return(
        status: 200,
        body: { candidates: [ { content: { parts: [ { text: '{}' } ] } } ] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)

    expect(captured_body.dig('contents', 0, 'parts', 1, 'inlineData', 'mimeType')).to eq('application/pdf')
    expect(captured_body.dig('contents', 0, 'parts', 1, 'inlineData', 'data')).to eq(Base64.strict_encode64("%PDF-1.4\nhello"))
  end

  it 'raises ApiError on timeout' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview')).to_timeout

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /timed out/)
  end

  it 'raises ApiError on timeout for text-only mode' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview')).to_timeout

    expect {
      described_class.generate_text(system_prompt: 'system', user_prompt: 'user')
    }.to raise_error(GeminiClient::ApiError, /timed out/)
  end

  it 'raises ApiError on other transport failures' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview')).to_raise(EOFError.new('socket closed'))

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /request failed: socket closed/)
  end

  it 'raises ApiError on system call transport failures' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview')).to_raise(Errno::ECONNREFUSED.new)

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /request failed/i)
  end

  it 'raises ApiError on a malformed success envelope' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(
        status: 200,
        body: [].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /Malformed response from Gemini: unexpected response envelope/)
  end

  it 'raises ApiError on malformed JSON for text-only mode' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(
        status: 200,
        body: 'not-json',
        headers: { 'Content-Type' => 'application/json' }
      )

    expect {
      described_class.generate_text(system_prompt: 'system', user_prompt: 'user')
    }.to raise_error(GeminiClient::ApiError, /Malformed response from Gemini/)
  end

  it 'raises ApiError when a success envelope contains non-hash parts' do
    stub_request(:post, endpoint_for('gemini-3.1-flash-lite-preview'))
      .to_return(
        status: 200,
        body: { candidates: [ { content: { parts: [ 'bad-part' ] } } ] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /Malformed response from Gemini: invalid content parts/)
  end
end
