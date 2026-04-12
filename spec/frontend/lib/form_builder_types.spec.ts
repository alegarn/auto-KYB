import { describe, expect, it } from 'vitest';

import { duplicateExportKeys, type FormField } from '@/components/customs/form-builder/types';

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

describe('duplicateExportKeys', () => {
  it('treats punctuation variants as duplicates within the same scope', () => {
    const fields: FormField[] = [
      buildField({ label: 'Phone Number', position: 1 }),
      buildField({ label: 'phone-number', position: 2 }),
    ];

    expect(duplicateExportKeys(fields)).toEqual(['phone-number']);
  });

  it('allows the same export key across different CRM object scopes', () => {
    const fields: FormField[] = [
      buildField({
        label: 'Contact Name',
        position: 1,
        metadata: {
          export_key: 'name',
          crm_mapping: {
            hubspot: { object_type: 'contact', property_name: 'firstname' },
          },
        },
      }),
      buildField({
        label: 'Company Name',
        position: 2,
        metadata: {
          export_key: 'name',
          crm_mapping: {
            hubspot: { object_type: 'company', property_name: 'name' },
          },
        },
      }),
    ];

    expect(duplicateExportKeys(fields)).toEqual([]);
  });
});