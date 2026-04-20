import { describe, expect, it } from 'vitest';

import {
  buildConfirmedFormData,
  buildErrorMessage,
  buildSummaryItems,
  isConfirmSuccessPayload,
  isPdfImportResult,
  validateClientFile,
  type PdfImportResult,
} from '@/lib/pdf-import-modal';
import type { FormField } from '@/components/customs/form-builder/types';

function createPdfFile(size = 128, name = 'import.pdf', type = 'application/pdf'): File {
  return new File([new Uint8Array(size)], name, { type });
}

function buildField(overrides: Partial<FormField>): FormField {
  return {
    label: 'Field',
    field_type: 'text',
    required: false,
    position: 1,
    metadata: {},
    ...overrides,
  };
}

function buildUploadResult(): PdfImportResult {
  return {
    form_data: {
      name: 'Imported Form',
      structure: {
        description: 'Imported from a PDF.',
        fields: [
          buildField({ label: 'Company name', field_type: 'text', position: 1 }),
          buildField({ label: 'Upload certificate', field_type: 'file', position: 2 }),
        ],
      },
    },
    warnings: ['Review generated options.'],
    field_count: 2,
  }
}

describe('validateClientFile', () => {
  it('accepts pdf files and rejects other file types', () => {
    expect(validateClientFile(createPdfFile())).toBeNull();
    expect(validateClientFile(createPdfFile(64, 'notes.txt', 'text/plain'))).toBe('Only PDF files are accepted.');
  });

  it('rejects files larger than 10 MB', () => {
    const largeFile = createPdfFile((10 * 1024 * 1024) + 1);

    expect(validateClientFile(largeFile)).toBe('File too large (max 10 MB).');
  });
});

describe('buildSummaryItems', () => {
  it('groups preview fields by category', () => {
    const fields: FormField[] = [
      buildField({ label: 'Text field', field_type: 'text', position: 1 }),
      buildField({ label: 'Select field', field_type: 'select', position: 2 }),
      buildField({ label: 'File field', field_type: 'file', position: 3 }),
      buildField({ label: 'Table field', field_type: 'table', position: 4 }),
      buildField({ label: 'Section title', field_type: 'section', position: 5 }),
    ];

    expect(buildSummaryItems(fields)).toEqual([
      { key: 'inputs', label: 'Inputs', count: 1 },
      { key: 'choices', label: 'Choices', count: 1 },
      { key: 'uploads', label: 'Uploads', count: 1 },
      { key: 'tables', label: 'Tables', count: 1 },
      { key: 'layout', label: 'Layout', count: 1 },
    ]);
  });
});

describe('buildErrorMessage', () => {
  it('returns the provided fallback when details are missing', () => {
    expect(buildErrorMessage(undefined, undefined, 'Could not create the form.')).toBe('Could not create the form.');
  });

  it('joins the backend error and detail list', () => {
    expect(buildErrorMessage('Invalid form data', ['Missing field label'])).toBe(
      'Invalid form data Missing field label',
    );
  });
});

describe('buildConfirmedFormData', () => {
  it('returns a new payload with the edited form name', () => {
    const uploadResult = buildUploadResult();
    const confirmed = buildConfirmedFormData(uploadResult.form_data, 'Renamed Imported Form');

    expect(confirmed).toEqual(
      expect.objectContaining({
        name: 'Renamed Imported Form',
        structure: uploadResult.form_data.structure,
      }),
    );
    expect(confirmed).not.toBe(uploadResult.form_data);
  });
});

describe('response guards', () => {
  it('accepts valid upload and confirm success payloads', () => {
    const uploadResult = buildUploadResult();

    expect(isPdfImportResult({ success: true, ...uploadResult })).toBe(true);
    expect(isConfirmSuccessPayload({ success: true, form_id: 'form-123' })).toBe(true);
  });

  it('rejects malformed payloads', () => {
    expect(isPdfImportResult({ success: true, form_data: {}, warnings: [], field_count: 2 })).toBe(false);
    expect(isConfirmSuccessPayload({ success: false, form_id: 'form-123' })).toBe(false);
  });
});
