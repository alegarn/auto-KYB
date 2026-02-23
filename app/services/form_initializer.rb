class FormInitializer

  DEFAULT_KYB = {
    name: "Default KYB Form",
    fields: [
      # Personal informations
      { label: "Profile", field_type: "section", metadata: { description: "Quick instructions: you can find government IDs at https://gov.example.com or on your passport/ID issuer account." }, required: false, position: 1 },
      { label: "Full Legal Name", field_type: "text", required: true, position: 2 },
      { label: "Date of Birth", field_type: "date", required: true, position: 3 },
      { label: "Nationality", field_type: "text", required: false, position: 4 },
      { label: "Residential Address", field_type: "textarea", required: false, position: 5 },
      { label: "Phone Number", field_type: "text", required: false, position: 6 },
      { label: "Email Address", field_type: "email", required: false, position: 7 },
      { label: "Upload Profile Photo", field_type: "file", required: false, position: 8 },
      { label: "Signature of Individual", field_type: "file", required: false, position: 9 },

      # KYC - identity verification
      { label: "KYC", field_type: "section", metadata: { description: "Documents & guidance: proof examples at https://docs.example.com/kyc or check your bank/identity provider." }, required: false, position: 10 },
      { label: "Government-issued ID Type & Number", field_type: "text", required: true, position: 11 },
      { label: "ID Issue Date", field_type: "date", required: false, position: 12 },
      { label: "ID Expiry Date", field_type: "date", required: false, position: 13 },
      { label: "Upload ID (Front)", field_type: "file", required: false, position: 14 },
      { label: "Upload ID (Back)", field_type: "file", required: false, position: 15 },
      { label: "Upload Proof of Address (utility bill, bank statement)", field_type: "file", required: false, position: 16 },
      { label: "Are you a Politically Exposed Person (PEP)?", field_type: "select", required: false, metadata: { options: [ "Yes", "No", "Prefer not to say" ] }, position: 17 },
      { label: "Source of Funds / Occupation", field_type: "textarea", required: false, position: 18 },

      # KYB - business
      { label: "KYB", field_type: "section", metadata: { description: "Business information and corporate documents." }, required: false, position: 19 },
      { label: "Legal Business Name", field_type: "text", required: true, position: 20 },
      { label: "Trading Name (if different)", field_type: "text", required: false, position: 21 },
      { label: "Business Registration Number", field_type: "text", required: false, position: 22 },
      { label: "Country of Incorporation", field_type: "text", required: false, position: 23 },
      { label: "Date of Incorporation", field_type: "date", required: false, position: 24 },
      { label: "Business Address", field_type: "textarea", required: false, position: 25 },
      { label: "Business Phone Number", field_type: "text", required: false, position: 26 },
      { label: "Business Email Address", field_type: "email", required: false, position: 27 },
      { label: "Business Website", field_type: "text", required: false, position: 28 },
      { label: "Nature of Business / Products Sold", field_type: "textarea", required: false, position: 29 },
      { label: "Regulatory Licenses (if applicable)", field_type: "text", required: false, position: 30 },
      { label: "Names of Directors", field_type: "textarea", required: false, position: 31 },
      { label: "Names of Shareholders (>25%)", field_type: "textarea", required: false, position: 32 },
      { label: "Ultimate Beneficial Owner (UBO) Information", field_type: "textarea", required: false, position: 33 },
      { label: "Authorized Signatory Name(s)", field_type: "textarea", required: false, position: 34 },
      { label: "Upload Certificate of Incorporation", field_type: "file", required: false, position: 35 },
      { label: "Upload Business Utility Bill", field_type: "file", required: false, position: 36 },
      { label: "Upload Company Tax ID or EIN", field_type: "file", required: false, position: 37 },
      { label: "Signature of Authorized Representative", field_type: "file", required: false, position: 38 },
      { label: "Date (business)", field_type: "date", required: false, position: 39 },

      # AML - anti money laundering
      { label: "AML", field_type: "section", metadata: { description: "Guidance: see basic AML checklist at https://aml.example.com and provide supporting docs." }, required: false, position: 40 },
      { label: "Politically Exposed Person (PEP) Details", field_type: "textarea", required: false, position: 41 },
      { label: "Sanctions / Watchlist Declarations", field_type: "textarea", required: false, position: 42 },
      { label: "Sanctions check consent", field_type: "checkbox", required: false, metadata: { options: [ "I consent" ] }, position: 43 },
      { label: "AML Policy Agreement (upload signed)", field_type: "file", required: false, position: 44 },
      { label: "Expected Monthly Volume (for AML risk scoring)", field_type: "number", required: false, position: 45 },

      # Services
      { label: "Services", field_type: "section", metadata: { description: "Select required services and read notes at https://services.example.com" }, required: false, position: 46 },
      { label: "Select required services", field_type: "checkbox", required: false, metadata: { options: [ "Payments", "Escrow", "High-risk processing", "Verification", "Legal advisory" ], allow_multiple: true }, position: 47 },
      { label: "PCI / Compliance required?", field_type: "checkbox", required: false, metadata: { options: [ "Yes" ] }, position: 48 },
      { label: "Additional agreements or attachments", field_type: "file", required: false, position: 49 },
      { label: "Contact person for services", field_type: "text", required: false, position: 50 }
    ]
  }.freeze

  def self.default_for_user(user)
    form = user.forms.create!(name: DEFAULT_KYB[:name], structure: { fields: DEFAULT_KYB[:fields] })
    DEFAULT_KYB[:fields].each do |f|
      form.form_fields.create!(
        label: f[:label],
        field_type: f[:field_type],
        required: f[:required],
        position: f[:position],
        metadata: f[:metadata] || {}
      )
    end
    form
  end

end
