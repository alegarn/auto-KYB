require "rails_helper"
require "csv"

RSpec.describe FormResponseExportService, type: :service do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  let(:client) { create(:client, user: user) }
  let(:client_form) { create(:client_form, client: client, form: form) }

  before do
    # ensure form_fields association works
  end

  describe "CSV generation" do
    it "includes header row with field labels" do
      create(:form_field, form: form, label: "First")
      create(:form_field, form: form, label: "Second")
      # reload client_form associations
      client_form.form.reload

      csv = FormResponseExportService.call(client_form)
      rows = CSV.parse(csv, row_sep: "\r\n")

      expect(rows.first).to include("Created At", "First", "Second")
    end

    it "includes data rows with response values" do
      f1 = create(:form_field, form: form, label: "One")
      f2 = create(:form_field, form: form, label: "Two")
      client_form.form.reload

      resp = client_form.form_responses.create!(data: { f1.id.to_s => "A", f2.id.to_s => "B" })

      csv = FormResponseExportService.call(client_form)
      rows = CSV.parse(csv, row_sep: "\r\n")

      expect(rows.length).to be >= 2
      expect(rows[1]).to include(resp.created_at.iso8601, "A", "B")
    end

    it "still generates header when there are no responses" do
      create(:form_field, form: form, label: "Only")
      client_form.form.reload

      csv = FormResponseExportService.call(client_form)
      rows = CSV.parse(csv, row_sep: "\r\n")

      expect(rows.first).to include("Only")
      expect(rows.length).to eq(1)
    end

    it "formats arrays and hashes for CSV" do
      f1 = create(:form_field, form: form, label: "Arr")
      f2 = create(:form_field, form: form, label: "Hsh")
      client_form.form.reload

      client_form.form_responses.create!(data: { f1.id.to_s => [ "a", "b" ], f2.id.to_s => { x: 1, y: 2 } })

      csv = FormResponseExportService.call(client_form)
      rows = CSV.parse(csv, row_sep: "\r\n")

      # array should be joined with '; '
      expect(rows[1]).to include("a; b")
      # hash should be formatted as "k: v; k2: v2"
      expect(rows[1].find { |c| c.include?("x:") && c.include?("y:") }).to be_present
    end

    it "uses field ids as keys when extracting data" do
      f1 = create(:form_field, form: form, label: "IdKey")
      client_form.form.reload

      client_form.form_responses.create!(data: { f1.id.to_s => "value123" })

      payload = FormResponseExportService.as_json_payload(client_form)

      field_key = f1.id.to_s
      expect(payload[:fields].map { |f| f[:id] }).to include(f1.id)
      expect(payload[:responses].first[:data][field_key][:value]).to eq("value123")
    end
  end

  describe "JSON payload" do
    it "returns expected structure" do
      f1 = create(:form_field, form: form, label: "LabelJson")
      client_form.form.reload
      client_form.form_responses.create!(data: { f1.id.to_s => "v" })

      payload = FormResponseExportService.as_json_payload(client_form)

      expect(payload[:client_form][:id]).to eq(client_form.id)
      expect(payload[:fields]).to be_an(Array)
      expect(payload[:responses]).to be_an(Array)
      expect(payload[:responses].first[:data].keys).to include(f1.id.to_s)
    end
  end
end
