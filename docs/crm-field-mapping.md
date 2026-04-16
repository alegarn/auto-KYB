# CRM Field Mapping & Data Export Guide

This document explains how form fields in Quick KYB are mapped to external CRM properties and how these mappings interact with internal data export keys (CSV/JSON).

## Concepts

There are three main "names" associated with any form field:
1. **Label**: What the front-end user sees (e.g., "What is your company's name?").
2. **Export Key**: The technical identifier used in CSV headers or JSON API responses (e.g., `company_name`).
3. **CRM Property**: The specific field in the external CRM (e.g., `name` in HubSpot or `Name` in Salesforce).

## CRM Field Mapping

The **CRM Field Mapping** modal allows you to connect individual form fields to specific objects in your connected CRMs.

### Object Types
Most integrations support mapping to:
- **Contact**: Individual person properties (Email, First Name, etc.).
- **Company**: Organizational properties (Company Name, Domain, etc.).

### Layout Elements Exclusion
Layout elements—such as **Sections**, **Subtitles**, **Text Blocks**, **Separators**, and **Logos**—are purely for form structure and design. Because they do not collect user input, they are explicitly excluded from:
- **CRM Mapping**: They do not appear in the CRM mapping modal.
- **Data Export Mapping**: They do not have an `export_key` and are invisible in the mapping sidebar.

> **Note on Restricted Properties**: Quick KYB automatically hides **Read-Only** and **Calculated** CRM properties (e.g., HubSpot's `engagements_last_meeting_booked`). This prevents integration errors that occur when attempting to write data to system-managed fields.

### Auto-Mapping
The "Auto-Map Fields" feature attempts to guess the correct CRM property by comparing the CRM's property labels and names against:
1. The field's **Export Key** (highest priority).
2. The field's **Label**.
3. The field's internal **Database ID**.

### Custom Properties
If a matching property doesn't exist in your CRM, you can select **"+ Create as Custom Property"**. During export, Quick KYB will attempt to create this property in your CRM before sending the data.

---

## Data Export Mapping (CSV/JSON)

The **Mapping** panel in the Form Builder sidebar lets you customize the technical keys used for external data consumers.

- **Default Behavior**: If left blank, the field's `Label` is used as the key.
- **Transformations**: You can bulk-transform labels into technical formats using the `snake_case`, `kebab-case`, or `camelCase` buttons.

---

## Key Alignment & Synchronization

To maintain consistency between your CSV reports and your CRM data, Quick KYB provides tools to keep `Export Keys` and `CRM Properties` in sync.

### 1. Manual Alignment (Per Field)
In the CRM Mapping modal, if a field's `Export Key` differs from the selected `CRM Property`, an **"Align Key"** button will appear. Clicking this updates the internal Export Key to match the CRM's technical property name.

### 2. Bulk Synchronization
In the Form Builder's Mapping sidebar, the **"Sync with CRM"** button will update *all* fields to use their mapped CRM property names as their export keys.

> **Note**: If a field is mapped to multiple CRMs (e.g., both HubSpot and Salesforce) with different property names, the sync tool prioritizes the first active connection found.

## Advanced Auto-Mapping

When the standard "Auto-Map Fields" leaves fields unmapped because labels differ semantically from CRM property names, you can run **AI Auto-Map Remaining** for a second-pass semantic match.

### How It Works

1. Click **"Auto-Map Fields"** to run the fast client-side matcher.
2. If fields still remain unmapped for a provider, click **"AI Auto-Map Remaining (N)"** in that provider's section.
3. The AI analyzes:
   - Each unmapped field's label, type, export key, and options.
   - The current draft field layout from the modal, including unsaved sections, subtitles, and option metadata.
   - The form's section structure and descriptive text for object-type inference (e.g., a field under "Company Details" likely maps to Company).
   - All available (non-read-only, non-already-mapped) CRM properties from your connected CRM.
4. Valid suggestions are merged into the draft mapping without overwriting existing manual selections.
5. Accepted suggestions appear in the table with an **"AI"** badge and a confidence indicator. Hovering the badge shows the AI reasoning.
6. If the AI cannot find a safe native CRM property, it can suggest a **custom property name** instead of forcing a bad match.
7. When the AI falls back to a custom property suggestion, Quick KYB now applies that suggestion directly to the draft as a **custom CRM mapping** on the inferred object (`Contact` or `Company` / `Account`, depending on the provider).
8. Review and save. Once saved, AI-generated mappings behave exactly like any other CRM mapping.

### Limitations

- The current CRM property inventory and AI auto-map flow are available for **HubSpot** connections. Unsupported CRM providers do not show the mapping modal until property inventory support is implemented.
- AI auto-map has **no built-in daily usage cap**.
- The AI action is only shown after the form has been created once, because the suggestion endpoint is attached to a persisted form.
- The AI action remains available even if no writable CRM properties remain, because the AI can still classify the field and fall back to a **custom property** suggestion.
- The AI only suggests mappings to writable CRM properties that are not already used elsewhere in the same provider mapping.
- **Type compatibility is enforced server-side** using the same compatibility rules as manual mapping. Invalid AI suggestions are discarded.
- When no safe native property exists, the AI can place the field into a **custom Contact/Company property mapping** with a generated technical property key. Saving the form keeps that custom mapping and triggers provider-specific property creation where supported.
- If the AI service is temporarily unavailable, Quick KYB shows an inline warning and you can continue using manual mapping or the standard auto-map.

### Export Key De-duplication After CRM Mapping

AI suggestions and CRM key alignment can legitimately produce the same export key more than once inside the same CRM object scope.

When that happens during CRM mapping save, Quick KYB now resolves the duplicates automatically:

1. It first keeps **cross-object duplicates** allowed. A `contact.name` field and a `company.name` field can still both use `name`.
2. If duplicates remain in the **same object scope**, Quick KYB appends nearby **section** or **subtitle** context to the generated export key.
3. If the contextual key is still not unique, Quick KYB adds a numeric suffix such as `_2`.

This keeps the visible field labels unchanged while ensuring the hidden export keys remain unique enough for form save, CSV/JSON export, and CRM routing.

### CRM Agnostic

Advanced Auto-Mapping works across supported CRM providers. Quick KYB uses the selected provider's writable property list when building AI suggestions, preferring cached schema data for speed and forcing a refresh only when no usable properties are available.

### Future Improvements

Follow-up iteration:

- Add telemetry logging for AI suggestion sessions so Quick KYB can compare the AI suggestions with the mappings the user ultimately saves.
- Store the user, form, provider, AI suggestions, and final mappings for analytics first, then reuse that data later for prompt-quality review or few-shot improvements.

---

## Best Practices

1. **Set Export Keys Early**: Define your technical keys before sharing the form to ensure CSV/JSON stability.
2. **Use technical names for keys**: Prefer `company_domain` over "What is your website?".
3. **Align with your Primary CRM**: If HubSpot is your main system of record, click "Sync with CRM" to ensure your CSV exports use the exact same property names as your HubSpot portal.
4. **Mind the Data Types**: Ensure your form field type (e.g., Date) is compatible with the CRM property type. Quick KYB will show a warning if it detects a potential mismatch.
5. **Use AI Auto-Map for complex forms**: If your form uses natural-language labels (e.g., "What is your company's legal name?"), run AI Auto-Map after the standard auto-map to catch semantic matches that string matching misses.
