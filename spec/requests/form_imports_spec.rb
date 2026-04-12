require 'rails_helper'

RSpec.describe 'Form Imports', type: :request do
  let(:user) { sign_in_user }
  let(:session_id) { user.sessions.last.id }
  let(:headers) do
    {
      'Cookie' => "session_token=#{session_id}",
      'Accept' => 'application/json',
      'REMOTE_ADDR' => '203.0.113.10'
    }
  end

  around do |example|
    original_enabled = Rack::Attack.enabled
    original_store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store.clear
    example.run
  ensure
    Rack::Attack.cache.store.clear
    Rack::Attack.cache.store = original_store
    Rack::Attack.enabled = original_enabled
  end

  def with_upload(content:, filename:, content_type: 'application/pdf')
    Tempfile.create([ File.basename(filename, '.*'), File.extname(filename) ]) do |file|
      file.binmode
      file.write(content)
      file.rewind
      uploaded_file = Rack::Test::UploadedFile.new(file.path, content_type, true, original_filename: filename)
      yield uploaded_file
    end
  end

  def minimal_pdf_content
    "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"
  end

  def valid_form_data
    {
      name: 'Imported Form',
      structure: {
        description: 'Imported from PDF',
        fields: [
          {
            label: 'Company name',
            field_type: 'text',
            required: true,
            position: 1,
            metadata: {}
          }
        ]
      }
    }
  end

  describe 'POST /form_imports' do
    it 'returns 422 when no file is provided' do
      post form_imports_path, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('success' => false, 'error' => 'No PDF file provided')
    end

    it 'returns 422 for an oversized file' do
      oversized_content = "%PDF-" + ('a' * (10.megabytes + 1))

      with_upload(content: oversized_content, filename: 'large.pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('success' => false, 'error' => 'File too large (max 10 MB)')
    end

    it 'returns 422 for a non-PDF signature' do
      with_upload(content: 'plain text', filename: 'fake.pdf', content_type: 'application/pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('success' => false, 'error' => 'Only PDF files are accepted')
    end

    it 'returns 422 for a malformed upload param' do
      post form_imports_path, params: { pdf_file: { bogus: 'value' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('success' => false, 'error' => 'Only PDF files are accepted')
    end

    it 'returns 200 with form_data for a valid PDF' do
      allow(PdfFormImportService).to receive(:call).and_return(
        PdfFormImportService::Result.new(success: true, data: valid_form_data.deep_stringify_keys, warnings: [ 'Review the imported field order.' ], errors: [])
      )

      with_upload(content: minimal_pdf_content, filename: 'import.pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
      end

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['success']).to be(true)
      expect(payload['field_count']).to eq(1)
      expect(payload.dig('form_data', 'name')).to eq('Imported Form')
    end

    it 'returns 422 when Gemini processing fails' do
      allow(PdfFormImportService).to receive(:call).and_raise(GeminiClient::ApiError, 'timeout')

      with_upload(content: minimal_pdf_content, filename: 'import.pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('success' => false, 'error' => 'AI processing failed. Please try again.')
    end

    it 'returns 422 when JSON extraction fails' do
      allow(PdfFormImportService).to receive(:call).and_raise(FormJsonExtractor::ExtractionError, 'bad json')

      with_upload(content: minimal_pdf_content, filename: 'import.pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('success' => false, 'error' => 'Could not interpret the AI response. Please try again.')
    end

    it 'returns 422 when validation fails' do
      allow(PdfFormImportService).to receive(:call).and_return(
        PdfFormImportService::Result.new(success: false, data: nil, warnings: [], errors: [ "Missing 'name'" ])
      )

      with_upload(content: minimal_pdf_content, filename: 'import.pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
      end

      expect(response).to have_http_status(:unprocessable_entity)
      payload = JSON.parse(response.body)
      expect(payload['error']).to eq('The generated form structure is invalid')
      expect(payload['details']).to include("Missing 'name'")
    end

    it 'requires authentication' do
      with_upload(content: minimal_pdf_content, filename: 'import.pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: { 'Accept' => 'application/json' }
      end

      expect(response).to have_http_status(:unauthorized)
    end

    it 'uses the IP and session token to scope the preview throttle' do
      throttle = Rack::Attack.throttles['form_imports/preview']
      discriminator_block = throttle.instance_variable_get(:@block)

      expect(throttle.instance_variable_get(:@limit)).to eq(5)
      expect(throttle.instance_variable_get(:@period)).to eq(60)

      request_with_cookie = Rack::Request.new(
        Rack::MockRequest.env_for(
          form_imports_path,
          method: 'POST',
          'REMOTE_ADDR' => '203.0.113.10',
          'HTTP_COOKIE' => 'session_token=throttle-test'
        )
      )
      request_without_cookie = Rack::Request.new(
        Rack::MockRequest.env_for(
          form_imports_path,
          method: 'POST',
          'REMOTE_ADDR' => '203.0.113.11'
        )
      )
      request_with_format = Rack::Request.new(
        Rack::MockRequest.env_for(
          "#{form_imports_path}.json",
          method: 'POST',
          'REMOTE_ADDR' => '203.0.113.12',
          'HTTP_COOKIE' => 'session_token=formatted-throttle-test'
        )
      )

      expect(discriminator_block.call(request_with_cookie)).to eq('203.0.113.10:throttle-test')
      expect(discriminator_block.call(request_without_cookie)).to eq('203.0.113.11:anonymous')
      expect(discriminator_block.call(request_with_format)).to eq('203.0.113.12:formatted-throttle-test')
    end

    it 'returns 429 on the sixth preview request in a minute' do
      allow(PdfFormImportService).to receive(:call).and_return(
        PdfFormImportService::Result.new(success: true, data: valid_form_data.deep_stringify_keys, warnings: [], errors: [])
      )

      5.times do
        with_upload(content: minimal_pdf_content, filename: 'import.pdf') do |uploaded_file|
          post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
        end

        expect(response).to have_http_status(:ok)
      end

      with_upload(content: minimal_pdf_content, filename: 'import.pdf') do |uploaded_file|
        post form_imports_path, params: { pdf_file: uploaded_file }, headers: headers
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)).to include('error' => 'Too many requests. Please try again later.')
    end
  end

  describe 'POST /form_imports/confirm' do
    it 'creates a form and returns its id' do
      expect {
        post confirm_form_imports_path, params: { form_data: valid_form_data }, headers: headers, as: :json
      }.to change { user.forms.count }.by(1)

      expect(response).to have_http_status(:created)
      payload = JSON.parse(response.body)
      expect(payload['success']).to be(true)
      expect(payload['form_id']).to be_present
      expect(user.forms.find(payload['form_id']).name).to eq('Imported Form')
    end

    it 'decodes HTML entities before creating the form' do
      form_data = {
        name: 'Imported &amp; Form',
        structure: {
          description: 'Use 5 &gt; 2',
          fields: [
            {
              label: 'Company &amp; name',
              field_type: 'text',
              required: true,
              position: 1,
              metadata: {}
            }
          ]
        }
      }

      post confirm_form_imports_path,
           params: { form_data: form_data },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)

      created_form = user.forms.find(JSON.parse(response.body)['form_id'])
      expect(created_form.name).to eq('Imported & Form')
      expect(created_form.structure['description']).to eq('Use 5 > 2')
      expect(created_form.form_fields.first.label).to eq('Company & name')
    end

    it 'returns 422 on invalid form data' do
      post confirm_form_imports_path,
           params: { form_data: { structure: { fields: [] } } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      payload = JSON.parse(response.body)
      expect(payload['success']).to be(false)
      expect(payload['details']).to include("Missing 'name'", "Missing or empty 'structure.fields'")
    end

    it 'returns 422 on a malformed non-hash payload' do
      post confirm_form_imports_path,
           params: { form_data: 'bad-payload' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include('success' => false, 'error' => 'Invalid form data')
    end

    it 'removes malformed nested CRM mapping metadata before creating the form' do
      form_data = valid_form_data.deep_dup
      form_data[:structure][:fields][0][:metadata] = { crm_mapping: 'bad-mapping' }

      post confirm_form_imports_path,
           params: { form_data: form_data },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)

      created_form = user.forms.find(JSON.parse(response.body)['form_id'])
      expect(created_form.form_fields.first.metadata).not_to have_key('crm_mapping')
    end

    it 'removes malformed nested file metadata before creating the form' do
      form_data = valid_form_data.deep_dup
      form_data[:structure][:fields][0][:field_type] = 'file'
      form_data[:structure][:fields][0][:metadata] = { file: 123 }

      post confirm_form_imports_path,
           params: { form_data: form_data },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)

      created_form = user.forms.find(JSON.parse(response.body)['form_id'])
      expect(created_form.form_fields.first.metadata).not_to have_key('file')
    end

    it 'replaces malformed nested table columns before creating the form' do
      form_data = valid_form_data.deep_dup
      form_data[:structure][:fields][0][:field_type] = 'table'
      form_data[:structure][:fields][0][:metadata] = { columns: [ 1 ] }

      post confirm_form_imports_path,
           params: { form_data: form_data },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)

      created_form = user.forms.find(JSON.parse(response.body)['form_id'])
      expect(created_form.form_fields.first.metadata['columns']).to eq([
        { 'key' => 'col_1', 'label' => 'Column 1', 'type' => 'text' }
      ])
    end

    it 'creates the form when duplicate labels can be disambiguated by section context' do
      form_data = {
        name: 'Imported Form',
        structure: {
          fields: [
            {
              label: 'KYC',
              field_type: 'section',
              required: false,
              position: 1,
              metadata: {}
            },
            {
              label: 'Phone Number',
              field_type: 'text',
              required: true,
              position: 2,
              metadata: {}
            },
            {
              label: 'KYB',
              field_type: 'section',
              required: false,
              position: 3,
              metadata: {}
            },
            {
              label: 'Phone Number',
              field_type: 'text',
              required: true,
              position: 4,
              metadata: {}
            }
          ]
        }
      }

      post confirm_form_imports_path,
           params: { form_data: form_data },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)

      created_form = user.forms.find(JSON.parse(response.body)['form_id'])
      phone_fields = created_form.form_fields.where(label: 'Phone Number').order(:position)

      expect(phone_fields.map { |field| field.metadata['export_key'] }).to eq([
        'phone_number_kyc',
        'phone_number_kyb'
      ])
    end

    it 'creates the form when duplicate labels repeat within the same section' do
      form_data = {
        name: 'Imported Form',
        structure: {
          fields: [
            {
              label: 'KYC',
              field_type: 'section',
              required: false,
              position: 1,
              metadata: {}
            },
            {
              label: 'Phone Number',
              field_type: 'text',
              required: true,
              position: 2,
              metadata: {}
            },
            {
              label: 'Phone Number',
              field_type: 'text',
              required: true,
              position: 3,
              metadata: {}
            }
          ]
        }
      }

      post confirm_form_imports_path,
           params: { form_data: form_data },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)

      created_form = user.forms.find(JSON.parse(response.body)['form_id'])
      phone_fields = created_form.form_fields.where(label: 'Phone Number').order(:position)

      expect(phone_fields.map { |field| field.metadata['export_key'] }).to eq([
        'phone_number_kyc',
        'phone_number_kyc_2'
      ])
    end

    it 'requires authentication' do
      post confirm_form_imports_path,
           params: { form_data: valid_form_data },
           headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json' },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 429 on the sixth confirm request in a minute' do
      allow(FormService).to receive(:create_form).and_return(instance_double(Form, id: 123))

      5.times do
        post confirm_form_imports_path,
             params: { form_data: valid_form_data },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:created)
      end

      post confirm_form_imports_path,
           params: { form_data: valid_form_data },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)).to include('error' => 'Too many requests. Please try again later.')
    end
  end
end
