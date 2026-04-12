require 'rails_helper'
require 'stringio'

RSpec.describe GeminiClient do
  let(:pdf_file) { StringIO.new("%PDF-1.4\nhello") }
  let(:endpoint) { 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.0-flash:generateContent' }

  around do |example|
    original_key = Rails.application.config.gemini.api_key
    Rails.application.config.gemini.api_key = 'test-gemini-key'
    example.run
  ensure
    Rails.application.config.gemini.api_key = original_key
  end

  it 'returns text from a successful API response' do
    stub_request(:post, endpoint)
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

  it 'raises ApiError on HTTP error responses' do
    stub_request(:post, endpoint).to_return(status: 500, body: 'upstream failure')

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
    stub_request(:post, endpoint)
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

    stub_request(:post, endpoint)
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
    stub_request(:post, endpoint).to_timeout

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /timed out/)
  end

  it 'raises ApiError on other transport failures' do
    stub_request(:post, endpoint).to_raise(EOFError.new('socket closed'))

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /request failed: socket closed/)
  end

  it 'raises ApiError on system call transport failures' do
    stub_request(:post, endpoint).to_raise(Errno::ECONNREFUSED.new)

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /request failed/i)
  end

  it 'raises ApiError on a malformed success envelope' do
    stub_request(:post, endpoint)
      .to_return(
        status: 200,
        body: [].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect {
      described_class.generate(system_prompt: 'system', user_prompt: 'user', pdf_file: pdf_file)
    }.to raise_error(GeminiClient::ApiError, /Malformed response from Gemini: unexpected response envelope/)
  end

  it 'raises ApiError when a success envelope contains non-hash parts' do
    stub_request(:post, endpoint)
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
