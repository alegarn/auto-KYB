require "rails_helper"

RSpec.describe Crm::AiFieldMapper do
  let(:provider) { "hubspot" }
  let(:user) { create(:user, plan: :pro, verified: true, subscription_status: :active) }
  let(:form) { create(:form, user: user, name: "KYB Intake") }
  let(:connection) { create(:crm_connection, user: user, provider: provider) }
  let(:provider_service) { instance_double(Crm::BaseService) }
  let(:already_mapped) { [] }
  let(:properties) do
    {
      contact: [
        { name: "email", label: "Email", type: "string", read_only: false },
        { name: "jobtitle", label: "Job Title", type: "string", read_only: false },
        { name: "lifecycle_stage", label: "Lifecycle Stage", type: "enumeration", field_type: "select", read_only: true }
      ],
      company: [
        { name: "name", label: "Company Name", type: "string", read_only: false },
        { name: "registration_number", label: "Registration Number", type: "string", read_only: false },
        { name: "annual_revenue", label: "Annual Revenue", type: "number", read_only: false }
      ]
    }
  end
  let!(:company_section) { create(:form_field, form: form, label: "Company Information", field_type: "section", position: 1, metadata: {}) }
  let!(:company_name_field) do
    create(:form_field, form: form, label: "What is your company's legal name?", field_type: "text", position: 2,
      metadata: { export_key: "company_name" })
  end
  let!(:email_field) do
    create(:form_field, form: form, label: "Work Email", field_type: "email", position: 3, metadata: {})
  end
  let(:unmapped_fields) do
    [
      { "id" => company_name_field.id.to_s, "label" => company_name_field.label, "field_type" => company_name_field.field_type },
      { "id" => email_field.id.to_s, "label" => email_field.label, "field_type" => email_field.field_type }
    ]
  end

  subject(:result) do
    described_class.new(
      form: form,
      connection: connection,
      unmapped_fields: unmapped_fields,
      already_mapped: already_mapped,
      provider: provider
    ).call
  end

  before do
    allow(Crm::ConnectionManager).to receive(:service_for).with(connection).and_return(provider_service)
    allow(provider_service).to receive(:fetch_properties).with(force: false).and_return(properties)
  end

  it "returns an empty result when there are no unmapped fields" do
    empty_result = described_class.new(
      form: form,
      connection: connection,
      unmapped_fields: [],
      already_mapped: [],
      provider: provider
    ).call

    expect(empty_result.suggestions).to eq({})
    expect(empty_result.unmapped_count).to eq(0)
    expect(empty_result.error).to be_nil
    expect(provider_service).not_to have_received(:fetch_properties)
  end

  it "fetches fresh properties, builds the prompt, and validates matching suggestions" do
    allow(GeminiClient).to receive(:generate_text).and_return(
      {
        company_name_field.id.to_s => {
          object_type: "company",
          property_name: "name",
          confidence: "high",
          reason: "Company section and label clearly point to the company name"
        },
        email_field.id.to_s => {
          object_type: "contact",
          property_name: "email",
          confidence: "medium",
          reason: "Email fields typically belong to contacts"
        }
      }.to_json
    )

    expect(result.error).to be_nil
    expect(result.unmapped_count).to eq(0)
    expect(result.suggestions).to eq(
      company_name_field.id.to_s => {
        object_type: "company",
        property_name: "name",
        confidence: "high",
        reason: "Company section and label clearly point to the company name"
      },
      email_field.id.to_s => {
        object_type: "contact",
        property_name: "email",
        confidence: "medium",
        reason: "Email fields typically belong to contacts"
      }
    )
    expect(provider_service).to have_received(:fetch_properties).with(force: false)
    expect(GeminiClient).to have_received(:generate_text) do |args|
      expect(args[:system_prompt]).to include("CRM field mapping assistant")
      expect(args[:user_prompt]).to include('### Section: "Company Information"')
      expect(args[:user_prompt]).to include('### Company Properties')
      expect(args[:user_prompt]).to include("What is your company's legal name?")
    end
  end

  it "uses provider-specific object labels in the prompt" do
    salesforce_connection = create(:crm_connection, user: user, provider: "salesforce")
    salesforce_service = instance_double(Crm::BaseService)

    allow(Crm::ConnectionManager).to receive(:service_for).with(salesforce_connection).and_return(salesforce_service)
    allow(salesforce_service).to receive(:fetch_properties).with(force: false).and_return(properties)
    allow(GeminiClient).to receive(:generate_text).and_return({}.to_json)

    described_class.new(
      form: form,
      connection: salesforce_connection,
      unmapped_fields: unmapped_fields,
      already_mapped: [],
      provider: "salesforce"
    ).call

    expect(salesforce_service).to have_received(:fetch_properties).with(force: false)
    expect(GeminiClient).to have_received(:generate_text) do |args|
      expect(args[:system_prompt]).to include("Account")
      expect(args[:user_prompt]).to include("### Account Properties")
    end
  end

  it "force refreshes properties when the cached property set is unusable" do
    allow(provider_service).to receive(:fetch_properties).with(force: false).and_return({ contact: [], company: [] })
    allow(provider_service).to receive(:fetch_properties).with(force: true).and_return(properties)
    allow(GeminiClient).to receive(:generate_text).and_return({}.to_json)

    result

    expect(provider_service).to have_received(:fetch_properties).with(force: false)
    expect(provider_service).to have_received(:fetch_properties).with(force: true)
  end

  it "rejects suggestions that point to unknown CRM properties" do
    allow(GeminiClient).to receive(:generate_text).and_return(
      {
        email_field.id.to_s => {
          object_type: "contact",
          property_name: "not_real",
          confidence: "high"
        }
      }.to_json
    )

    expect(result.suggestions).to eq({})
    expect(result.unmapped_count).to eq(2)
  end

  it "rejects suggestions with incompatible field types" do
    revenue_field = create(:form_field, form: form, label: "Revenue", field_type: "number", position: 4, metadata: {})
    allow(GeminiClient).to receive(:generate_text).and_return(
      {
        revenue_field.id.to_s => {
          object_type: "company",
          property_name: "name",
          confidence: "high"
        }
      }.to_json
    )

    number_result = described_class.new(
      form: form,
      connection: connection,
      unmapped_fields: [ { "id" => revenue_field.id.to_s, "label" => revenue_field.label, "field_type" => revenue_field.field_type } ],
      already_mapped: [],
      provider: provider
    ).call

    expect(number_result.suggestions).to eq({})
    expect(number_result.unmapped_count).to eq(1)
  end

  it "keeps valid custom property suggestions with sanitized technical names" do
    allow(GeminiClient).to receive(:generate_text).and_return(
      {
        company_name_field.id.to_s => {
          object_type: "company",
          property_name: nil,
          confidence: "medium",
          suggest_custom: true,
          suggested_custom_name: "SIREN Number!!",
          reason: "No existing property exactly matches this national identifier"
        }
      }.to_json
    )

    custom_result = described_class.new(
      form: form,
      connection: connection,
      unmapped_fields: [ { "id" => company_name_field.id.to_s, "label" => "SIREN number", "field_type" => "text" } ],
      already_mapped: [],
      provider: provider
    ).call

    expect(custom_result.suggestions).to eq(
      company_name_field.id.to_s => {
        object_type: "company",
        property_name: nil,
        confidence: "medium",
        reason: "No existing property exactly matches this national identifier",
        suggest_custom: true,
        suggested_custom_name: "siren_number"
      }
    )
  end

  it "filters out already mapped properties before validation" do
    allow(GeminiClient).to receive(:generate_text).and_return(
      {
        email_field.id.to_s => {
          object_type: "contact",
          property_name: "email",
          confidence: "high"
        }
      }.to_json
    )

    mapped_result = described_class.new(
      form: form,
      connection: connection,
      unmapped_fields: [ { "id" => email_field.id.to_s, "label" => email_field.label, "field_type" => email_field.field_type } ],
      already_mapped: [ "contact::email" ],
      provider: provider
    ).call

    expect(mapped_result.suggestions).to eq({})
    expect(mapped_result.unmapped_count).to eq(1)
  end

  it "sanitizes prompt labels before sending them to Gemini" do
    company_name_field.update!(label: %(<script>alert("x")</script> Company Name))
    allow(GeminiClient).to receive(:generate_text).and_return({}.to_json)

    result

    expect(GeminiClient).to have_received(:generate_text) do |args|
      expect(args[:user_prompt]).not_to include("<script>")
      expect(args[:user_prompt]).to include("Company Name")
      expect(args[:user_prompt]).not_to include(">")
    end
  end

  it "returns a graceful error when Gemini is unavailable" do
    allow(GeminiClient).to receive(:generate_text).and_raise(GeminiClient::ApiError, "down")
    allow(Rails.logger).to receive(:error)

    expect(result.suggestions).to eq({})
    expect(result.unmapped_count).to eq(2)
    expect(result.error).to eq(:ai_unavailable)
    expect(Rails.logger).to have_received(:error).with(/AiFieldMapper/)
  end

  it "returns a graceful error when the AI response cannot be parsed" do
    allow(GeminiClient).to receive(:generate_text).and_return("not-json")
    allow(FormJsonExtractor).to receive(:call).and_raise(FormJsonExtractor::ExtractionError, "bad json")
    allow(Rails.logger).to receive(:error)

    expect(result.suggestions).to eq({})
    expect(result.unmapped_count).to eq(2)
    expect(result.error).to eq(:ai_unavailable)
  end
end
