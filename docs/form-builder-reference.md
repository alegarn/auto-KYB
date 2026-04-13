# Form Builder Reference

This is the canonical reference for the form builder schema.

The machine-readable source lives in [app/frontend/components/customs/form-builder/reference.ts](app/frontend/components/customs/form-builder/reference.ts). This document is the human-readable view of the same schema.

## Payload Shape

```json
{
  "name": "Default KYB Form",
  "structure": {
    "settings": {
      "primary_color": "#2563eb",
      "form_background_color": "#ffffff",
      "header_background_color": "#f8fafc"
    },
    "fields": [
      {
        "label": "Full Legal Name",
        "field_type": "text",
        "required": true,
        "position": 1,
        "metadata": {}
      }
    ]
  }
}
```

Universal rules:

- `label`, `field_type`, `required`, `position`, and `metadata` are present on every field.
- `id` is only present when updating an existing field.
- `metadata` is the canonical place for field-specific configuration.
- The controller still accepts top-level `options` and `allow_multiple`, but the service persists `metadata` only. Keep choice configuration in `metadata`.
- `export_key` and `crm_mapping` are handled by the mapping panel and apply only to data fields, not layout fields.

## Form Settings

| Key | Used in builder | Used in live form | Notes |
| --- | --- | --- | --- |
| `primary_color` | yes | yes | Submit button and accent color. |
| `form_background_color` | yes | yes | Background for the form surface. |
| `header_background_color` | yes | yes | Optional header strip background. |
| `logo_url` | no | no | Declared in the type but not currently consumed by the form screens. |

## Field Types

| Field type | Category | Builder controls | Live metadata | Notes |
| --- | --- | --- | --- | --- |
| `text` | Input | placeholder, description, validation.min_length, validation.max_length, validation.pattern | placeholder | Validation is captured by the builder but not enforced by the live renderer yet. |
| `number` | Input | placeholder, description, validation.min, validation.max | placeholder | Validation is captured by the builder but not enforced by the live renderer yet. |
| `email` | Input | placeholder, description, validation.min_length, validation.max_length, validation.pattern | placeholder | Validation is captured by the builder but not enforced by the live renderer yet. |
| `date` | Input | description | none | The builder does not currently expose date-specific validation or placeholder controls. |
| `textarea` | Input | placeholder, description, validation.min_length, validation.max_length, validation.pattern | placeholder | Validation is captured by the builder but not enforced by the live renderer yet. |
| `select` | Choice | options, description | options | Single choice by default. |
| `radio` | Choice | options, description | options | Single choice by default. |
| `checkbox` | Choice | options, allow_multiple, description | options, allow_multiple | `allow_multiple` toggles between a single value and multi-select behavior. |
| `buttons` | Choice (UI) | options, allow_multiple, description | options, allow_multiple | UI button group. The value model matches the choice fields. |
| `file` | Data | file.max_size_kb, file.allowed_types | file.max_size_kb, file.allowed_types | The live uploader also enforces backend file constraints. |
| `table` | Data | columns[].key, columns[].label, columns[].type | columns[] | `metadata.columns` is the live source of truth; `metadata.table` exists as a richer config object but is not currently edited by the builder. |
| `section` | Layout | description, section.border_style | description, section.border_style | `section.collapsible` and `section.default_expanded` are declared but not currently exposed in the builder UI. |
| `subtitle` | Layout | description | description | Simple heading-style layout block. |
| `static_text` | Layout | text_content | text_content, description | The live renderer falls back to `description` when `text_content` is blank. |
| `separator` | Layout | separator.thickness, separator.margin | separator.thickness, separator.margin | `separator.color` is declared but not currently surfaced in the builder UI. |
| `logo` | Layout | logo.image_url, logo.width, logo.height, logo.alignment | logo.image_url, logo.width, logo.height, logo.alignment | Image-based layout block. |

## Metadata Catalog

Generic metadata keys can appear on any field type, but some are only meaningful in specific contexts:

- `description`: helper text and section copy.
- `instruction`: declared in the schema but not currently surfaced in the UI.
- `export_key`: export/mapping key used for CSV and JSON output. PDF import may synthesize this when repeated labels would otherwise collide.
- `crm_mapping`: provider-specific CRM mapping configuration.
- `placeholder`: input-only helper for text-like fields.
- `validation`: input-only validation rules.
- `options`: choice list for select, radio, checkbox, and buttons.
- `allow_multiple`: multi-select flag for checkbox and buttons.
- `file`: file upload configuration.
- `columns` and `table`: table field configuration.
- `section`: section layout configuration.
- `text_content`: static text block content.
- `separator`: separator styling.
- `logo`: logo styling.

```ts
type CrmMapping = {
  type?: 'existing' | 'custom';
  property_name?: string;
  object_type?: 'contact' | 'company' | string;
};
```

`property_name` may also be stored as a compound key such as `company::name`; the CRM normalization path can strip or restore the object prefix.

| Field type | Exact metadata shape | Builder / renderer behavior | Notes |
| --- | --- | --- | --- |
| `text` | `placeholder?: string; validation?: { min_length?: number; max_length?: number; pattern?: string }` | Placeholder editor and validation editor are shown. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. Validation is builder-only today. |
| `number` | `placeholder?: string; validation?: { min?: number; max?: number }` | Placeholder editor and numeric validation editor are shown. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. Validation is builder-only today. |
| `email` | `placeholder?: string; validation?: { min_length?: number; max_length?: number; pattern?: string }` | Placeholder editor and validation editor are shown. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. Validation is builder-only today. |
| `date` | `none required` | Only the description helper is surfaced in the builder. | `description`, `instruction`, `export_key`, and `crm_mapping` may still be stored, but there is no date-specific metadata editor yet. |
| `textarea` | `placeholder?: string; validation?: { min_length?: number; max_length?: number; pattern?: string }` | Placeholder editor and validation editor are shown. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. Validation is builder-only today. |
| `select` | `options?: string[]` | Choices are editable in the builder; live renderer reads `options`. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. `allow_multiple` is not used here. |
| `radio` | `options?: string[]` | Choices are editable in the builder; live renderer reads `options`. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. `allow_multiple` is not used here. |
| `checkbox` | `options?: string[]; allow_multiple?: boolean` | Choices are editable in the builder; live renderer reads `options` and `allow_multiple`. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. |
| `buttons` | `options?: string[]; allow_multiple?: boolean` | Choice-button UI uses the same option model as checkbox. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. This is a UI choice field, not a layout field. |
| `file` | `file?: { allowed_types?: string[]; max_size_kb?: number }` | Builder edits file size and allowed types; live renderer hands config to the uploader. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. Backend file limits still apply. |
| `table` | `columns?: TableColumn[]; table?: { columns: TableColumn[]; min_rows?: number; max_rows?: number; default_row_count?: number; allow_add_rows?: boolean }` | Builder edits `columns`; live renderer reads `columns`. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored. `metadata.table` is richer but currently builder-seeded only. |
| `section` | `section?: { collapsible?: boolean; default_expanded?: boolean; border_style?: 'none' \| 'subtle' \| 'prominent' }` | Section title and description are editable. | `instruction`, `export_key`, and `crm_mapping` can also be stored, but export logic ignores layout fields. `collapsible` is declared but not exposed in the current UI. |
| `subtitle` | `none required` | Subtitle text and description are editable. | `instruction`, `export_key`, and `crm_mapping` can also be stored, but export logic ignores layout fields. |
| `static_text` | `text_content?: string` | Builder edits the text block body; live renderer falls back to description when blank. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored, but export logic ignores layout fields. |
| `separator` | `separator?: { thickness?: 'thin' \| 'medium' \| 'thick'; color?: string; margin?: 'small' \| 'medium' \| 'large' }` | Builder edits thickness and spacing; live renderer only uses thickness and margin. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored, but export logic ignores layout fields. `color` is declared but not currently surfaced. |
| `logo` | `logo?: { image_url?: string; width?: number; height?: number; alignment?: 'left' \| 'center' \| 'right' }` | Builder edits image URL, size, and alignment; live renderer shows the image if `image_url` is set. | `description`, `instruction`, `export_key`, and `crm_mapping` can also be stored, but export logic ignores layout fields. |

## Legacy Type

| Field type | Status | Notes |
| --- | --- | --- |
| `button` | legacy only | Allowed by the Rails model validation but not exposed in the palette or renderer. |

## Practical Notes

- If you are generating form JSON, prefer `metadata` over top-level choice keys.
- `validation` is present in the schema, but the current live form does not enforce it.
- Layout fields are supported by the builder and live preview, but they are skipped by export mapping and CRM sync.
- PDF import keeps repeated visible labels when they appear in different sections, but it may generate context-aware `export_key` values so exports stay unique.
- The `table` field currently uses `metadata.columns` in the renderer; keep `metadata.table` in sync if you populate it programmatically.
