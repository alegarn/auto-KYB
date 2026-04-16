require "rails_helper"

RSpec.describe "Forms::AiFieldSuggestions", type: :request do
  def reset_request_cookies!
    return unless respond_to?(:cookies)
    return unless cookies.respond_to?(:to_hash)

    cookies.to_hash.each_key { |name| cookies.delete(name) }
  end

  def signed_session_cookie_header(session_id)
    request = ActionDispatch::TestRequest.create
    jar = request.cookie_jar
    jar.signed[:session_token] = session_id
    jar.to_hash.map { |name, value| "#{name}=#{value}" }.join("; ")
  end

  let(:mapper_result) do
    Crm::AiFieldMapper::Result.new(
      suggestions: { "field-1" => { object_type: "contact", property_name: "email", confidence: "high" } },
      unmapped_count: 0,
      error: nil
    )
  end
  let(:mapper) { instance_double(Crm::AiFieldMapper, call: mapper_result) }

  around do |example|
    original_enabled = Rack::Attack.enabled
    original_store = Rack::Attack.cache.store

    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store.clear
    Rails.cache.clear
    Current.session = nil
    reset_request_cookies!

    example.run
  ensure
    Current.session = nil
    reset_request_cookies!
    Rails.cache.clear
    Rack::Attack.cache.store.clear
    Rack::Attack.cache.store = original_store
    Rack::Attack.enabled = original_enabled
  end

  describe "POST /forms/:form_id/ai_field_suggestions" do
    let(:user) { sign_in_user(create(:user, plan: :pro, verified: true, subscription_status: :active)) }
    let(:session_id) { user.sessions.last.id }
    let(:headers) { { "Cookie" => "session_token=#{session_id}" } }
    let(:form) { create(:form, user: user) }
    let!(:form_field) { create(:form_field, form: form, label: "Work Email", field_type: "email", position: 1, metadata: {}) }
    let!(:connection) { create(:crm_connection, user: user, provider: "hubspot", status: "active") }
    let(:request_params) do
      {
        provider: "hubspot",
        unmapped_fields: [
          { id: form_field.id, label: form_field.label, field_type: form_field.field_type }
        ],
        already_mapped: []
      }
    end

    before do
      allow(Crm::AiFieldMapper).to receive(:new).and_return(mapper)
    end

    it "returns 401 when unauthenticated" do
      Current.session = nil
      reset_request_cookies!
      public_owner = create(:user, plan: :pro, verified: true, subscription_status: :active)
      public_form = create(:form, user: public_owner)
      public_field = create(:form_field, form: public_form, label: "Work Email", field_type: "email", position: 1, metadata: {})

      post "/forms/#{public_form.id}/ai_field_suggestions",
        params: {
          provider: "hubspot",
          unmapped_fields: [ { id: public_field.id, label: public_field.label, field_type: public_field.field_type } ],
          already_mapped: []
        },
        headers: { "Cookie" => "", "REMOTE_ADDR" => "203.0.113.10" },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 when the user is not CRM-plan eligible" do
      basic_user = sign_in_user(create(:user, plan: :basic, verified: true, subscription_status: :active))
      basic_form = create(:form, user: basic_user)
      create(:form_field, form: basic_form, label: "Work Email", field_type: "email", position: 1, metadata: {})
      create(:crm_connection, user: basic_user, provider: "hubspot", status: "active")

      post "/forms/#{basic_form.id}/ai_field_suggestions",
        params: {
          provider: "hubspot",
          unmapped_fields: [ { id: basic_form.form_fields.first.id, label: "Work Email", field_type: "email" } ],
          already_mapped: []
        },
        headers: { "Cookie" => "session_token=#{basic_user.sessions.last.id}" },
        as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to include("error" => "plan_insufficient")
    end

    it "returns 422 when provider is missing" do
      post "/forms/#{form.id}/ai_field_suggestions",
        params: { unmapped_fields: request_params[:unmapped_fields], already_mapped: [] },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to include("error" => "provider_required")
    end

    it "returns validated suggestions" do
      post "/forms/#{form.id}/ai_field_suggestions", params: request_params, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(
        "suggestions" => { "field-1" => { "object_type" => "contact", "property_name" => "email", "confidence" => "high" } },
        "unmapped_count" => 0,
        "error" => nil
      )
      expect(Crm::AiFieldMapper).to have_received(:new).with(
        form: form,
        connection: connection,
        unmapped_fields: kind_of(Array),
        already_mapped: [],
        provider: "hubspot"
      )
    end

    it "returns a successful response with an ai_unavailable error payload" do
      unavailable_result = Crm::AiFieldMapper::Result.new(
        suggestions: {},
        unmapped_count: 1,
        error: :ai_unavailable
      )
      allow(mapper).to receive(:call).and_return(unavailable_result)

      post "/forms/#{form.id}/ai_field_suggestions", params: request_params, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(
        "suggestions" => {},
        "unmapped_count" => 1,
        "error" => "ai_unavailable"
      )
    end

    context "when the daily AI suggestion limit is exceeded" do
      it "returns 429 after the rate limit is exceeded" do
        10.times do
          post "/forms/#{form.id}/ai_field_suggestions", params: request_params, headers: headers, as: :json
          expect(response).to have_http_status(:ok)
        end

        post "/forms/#{form.id}/ai_field_suggestions", params: request_params, headers: headers, as: :json

        expect(response).to have_http_status(:too_many_requests)
        expect(JSON.parse(response.body)).to include("error" => "rate_limited")
      end

      it "shares the limit across signed sessions for the same user" do
        second_session = user.sessions.create!
        signed_headers = [
          { "Cookie" => signed_session_cookie_header(session_id) },
          { "Cookie" => signed_session_cookie_header(second_session.id) }
        ]

        Current.session = nil
        reset_request_cookies!

        10.times do |index|
          post "/forms/#{form.id}/ai_field_suggestions",
            params: request_params,
            headers: signed_headers[index % signed_headers.length],
            as: :json

          expect(response).to have_http_status(:ok)
        end

        post "/forms/#{form.id}/ai_field_suggestions",
          params: request_params,
          headers: signed_headers.last,
          as: :json

        expect(response).to have_http_status(:too_many_requests)
        expect(JSON.parse(response.body)).to include("error" => "rate_limited")
      end
    end
  end
end
