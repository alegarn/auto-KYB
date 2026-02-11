class FormInitializer

  DEFAULT_KYB = {
    name: "Default KYB Form",
    fields: [
      # KYC - personal
      { label: "Full Legal Name", field_type: "text", required: true, position: 1 },
      { label: "Date of Birth", field_type: "date", required: false, position: 2 },
      { label: "Nationality", field_type: "text", required: false, position: 3 },
      { label: "Residential Address", field_type: "textarea", required: false, position: 4 },
      { label: "Phone Number", field_type: "text", required: false, position: 5 },
      { label: "Email Address", field_type: "email", required: false, position: 6 },
      { label: "Government-issued ID Type & Number", field_type: "text", required: false, position: 7 },
      { label: "ID Issue Date / Expiry", field_type: "text", required: false, position: 8 },
      { label: "Upload Proof of Address", field_type: "file", required: false, position: 9 },
      { label: "Source of Funds / Occupation", field_type: "text", required: false, position: 10 },
      { label: "Are you a Politically Exposed Person (PEP)?", field_type: "text", required: false, position: 11 },
      { label: "Signature of Individual", field_type: "file", required: false, position: 12 },
      { label: "Date (personal)", field_type: "date", required: false, position: 13 },

      # KYB - business
      { label: "Legal Business Name", field_type: "text", required: true, position: 14 },
      { label: "Trading Name (if different)", field_type: "text", required: false, position: 15 },
      { label: "Business Registration Number", field_type: "text", required: false, position: 16 },
      { label: "Country of Incorporation", field_type: "text", required: false, position: 17 },
      { label: "Date of Incorporation", field_type: "date", required: false, position: 18 },
      { label: "Business Address", field_type: "textarea", required: false, position: 19 },
      { label: "Business Phone Number", field_type: "text", required: false, position: 20 },
      { label: "Business Email Address", field_type: "email", required: false, position: 21 },
      { label: "Business Website", field_type: "text", required: false, position: 22 },
      { label: "Nature of Business / Products Sold", field_type: "textarea", required: false, position: 23 },
      { label: "Expected Monthly Volume", field_type: "number", required: false, position: 24 },
      { label: "Source of Funds", field_type: "text", required: false, position: 25 },
      { label: "Regulatory Licenses (if applicable)", field_type: "text", required: false, position: 26 },
      { label: "Names of Directors", field_type: "textarea", required: false, position: 27 },
      { label: "Names of Shareholders (>25%)", field_type: "textarea", required: false, position: 28 },
      { label: "Ultimate Beneficial Owner (UBO) Information", field_type: "textarea", required: false, position: 29 },
      { label: "Authorized Signatory Name(s)", field_type: "textarea", required: false, position: 30 },
      { label: "Upload Certificate of Incorporation", field_type: "file", required: false, position: 31 },
      { label: "Upload Business Utility Bill", field_type: "file", required: false, position: 32 },
      { label: "Upload Company Tax ID or EIN", field_type: "file", required: false, position: 33 },
      { label: "Signature of Authorized Representative", field_type: "file", required: false, position: 34 },
      { label: "Date (business)", field_type: "date", required: false, position: 35 }
    ]
  }.freeze

  def self.default_for_user(user)
    form = user.forms.create!(name: DEFAULT_KYB[:name], structure: { fields: DEFAULT_KYB[:fields] })
    DEFAULT_KYB[:fields].each do |f|
      form.form_fields.create!(label: f[:label], field_type: f[:field_type], required: f[:required], position: f[:position])
    end
    form
  end

end
