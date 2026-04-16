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
   - The form's section structure and descriptive text for object-type inference (e.g., a field under "Company Details" likely maps to Company).
   - All available (non-read-only, non-already-mapped) CRM properties from your connected CRM.
4. Valid suggestions are merged into the draft mapping without overwriting existing manual selections.
5. Accepted suggestions appear in the table with an **"AI"** badge and a confidence indicator. Hovering the badge shows the AI reasoning.
6. If the AI cannot find a safe native CRM property, it can suggest a **custom property name** instead of forcing a bad match.
7. Review and save. Once saved, AI-generated mappings behave exactly like any other CRM mapping.

### Limitations

- Maximum **10 AI auto-map requests per day**.
- The AI only suggests mappings to writable CRM properties that are not already used elsewhere in the same provider mapping.
- **Type compatibility is enforced server-side** using the same compatibility rules as manual mapping. Invalid AI suggestions are discarded.
- When no safe native property exists, the UI can suggest a **custom property name**, but it does not silently create that property for you.
- If the AI service is temporarily unavailable, Quick KYB shows an inline warning and you can continue using manual mapping or the standard auto-map.

### CRM Agnostic

Advanced Auto-Mapping works across supported CRM providers. Quick KYB refreshes the writable property list from the selected provider before asking the AI for suggestions, so the semantic matcher works against your current CRM schema.

---

## Best Practices

1. **Set Export Keys Early**: Define your technical keys before sharing the form to ensure CSV/JSON stability.
2. **Use technical names for keys**: Prefer `company_domain` over "What is your website?".
3. **Align with your Primary CRM**: If HubSpot is your main system of record, click "Sync with CRM" to ensure your CSV exports use the exact same property names as your HubSpot portal.
4. **Mind the Data Types**: Ensure your form field type (e.g., Date) is compatible with the CRM property type. Quick KYB will show a warning if it detects a potential mismatch.
5. **Use AI Auto-Map for complex forms**: If your form uses natural-language labels (e.g., "What is your company's legal name?"), run AI Auto-Map after the standard auto-map to catch semantic matches that string matching misses.
