# PDF Form Import

## Overview

The PDF form import flow lets a signed-in user upload a PDF from the forms index, send that file directly to Gemini as a multimodal attachment, review the generated form preview, and only then create a real Quick KYB form.

The flow is split into two HTTP steps:

- `POST /form_imports` uploads the PDF and returns a preview payload as JSON.
- `POST /form_imports/confirm` revalidates the preview payload, persists the form through `FormService`, and returns the new form id.

## Architecture

The backend pipeline lives in `app/services/`:

- `GeminiPdfInput` base64-encodes the uploaded PDF into a Gemini inline data part.
- `GeminiClient` sends the prompt and PDF to Gemini Flash and extracts the raw text response.
- `FormJsonExtractor` strips fences/prose and parses the JSON object from the model response.
- `FormJsonValidator` validates and normalizes the payload to the live builder schema.
- `PdfFormImportService` orchestrates the pipeline and strips HTML from returned string values.

The controller boundary lives in `FormImportsController`:

- `create` enforces file size and PDF signature checks before calling the service.
- `confirm` revalidates the client-supplied preview payload before creating the form.

The frontend entry point is the forms index page. `PdfImportModal.svelte` uses a sheet, client-side file checks, `fetch()` for JSON endpoints, and `router.visit()` only after persistence succeeds.

## Configuration

Gemini credentials are loaded from Rails credentials first, then from the environment:

```yaml
gemini:
  api_key: your_api_key_here
```

Fallback environment variable:

```bash
GEMINI_API_KEY=your_api_key_here
```

The initializer is in `config/initializers/gemini.rb`.

## Schema Mapping

The generated payload must match the live form builder schema used by `FormService` and the Svelte form builder reference.

Required root shape:

```json
{
  "name": "Imported Form",
  "structure": {
    "description": "Optional summary",
    "settings": {
      "primary_color": "#2563eb",
      "form_background_color": "#ffffff",
      "header_background_color": "#f8fafc"
    },
    "fields": [
      {
        "label": "Company name",
        "field_type": "text",
        "required": true,
        "position": 1,
        "metadata": {}
      }
    ]
  }
}
```

The validator accepts the active field types used by the builder and normalizes choice/table/file/layout metadata to the same shapes the frontend expects.

## Validation And Corrections

Hard errors:

- missing `name`
- missing `structure`
- missing or empty `structure.fields`
- any field that is not an object
- any field missing `label`

Automatic corrections:

- unknown field types are downgraded to `text`
- field positions are resequenced to `1..N`
- invalid `metadata` values are reset to `{}`
- choice fields missing options get placeholder options
- top-level `options` and `allow_multiple` are folded into `metadata`
- table fields missing `metadata.columns` get a placeholder text column
- settings are merged with the app defaults when keys are missing

The controller also revalidates the preview payload during confirm so edited client-side data cannot bypass the server-side schema rules.

## Security Considerations

- Only authenticated users with access to forms can hit the endpoints.
- Uploads are limited to 10 MB before the Gemini request runs.
- PDF acceptance is enforced with magic-byte validation (`%PDF-`), not just the browser filename or MIME type.
- Gemini API keys are sent in the `x-goog-api-key` header instead of the URL.
- Returned strings are stripped of HTML tags before the preview or persisted form uses them.
- `Rack::Attack` throttles `POST /form_imports` to 5 requests per minute per session (with IP fallback).

## Testing

Relevant automated coverage:

- Ruby services: `spec/services/gemini_pdf_input_spec.rb`, `spec/services/gemini_client_spec.rb`, `spec/services/form_json_extractor_spec.rb`, `spec/services/form_json_validator_spec.rb`, `spec/services/pdf_form_import_service_spec.rb`
- Request coverage: `spec/requests/form_imports_spec.rb`
- Frontend component coverage: `spec/frontend/components/customs/PdfImportModal.spec.ts`
- Browser flow coverage: `spec/system/pdf_form_import_spec.rb`

Useful commands:

```bash
bundle exec rspec spec/services/gemini_pdf_input_spec.rb spec/services/gemini_client_spec.rb spec/services/form_json_extractor_spec.rb spec/services/form_json_validator_spec.rb spec/services/pdf_form_import_service_spec.rb spec/requests/form_imports_spec.rb spec/system/pdf_form_import_spec.rb
npm run test:unit -- spec/frontend/components/customs/PdfImportModal.spec.ts
bundle exec rake js:routes
```

## Limitations And Follow-Up

- The import is synchronous. Large or slow PDFs still block the request/response cycle.
- There is no page-count guard yet; the implementation currently relies on file size.
- Image-only or badly scanned PDFs still depend on Gemini extracting enough structure.
- The preview currently edits only the form name. A richer structured edit step would require a dedicated preview editor.