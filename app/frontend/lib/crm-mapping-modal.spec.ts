import { describe, expect, it } from 'vitest';
import {
  applyCrmExportKeyAlignment,
  applyCrmMappingSelection,
  applyCrmOptionsSync,
  buildCrmMappingFieldLookup,
  countAvailableWritableCrmProperties,
  getCrmMappingFieldStateKey,
  getCrmMappingPropertyName,
  getCrmMappingSelectionValue,
  hydrateCrmMappingDraft,
  mergeAiSuggestionsDraft,
  mergeCrmAutoMappedDraft,
  serializeCrmMappingFields,
  type CrmMappings,
} from './crm-mapping-modal';

describe('crm-mapping-modal helpers', () => {
  it('hydrates legacy mappings into normalized compound keys', () => {
    const draft = hydrateCrmMappingDraft([
      {
        field: {
          id: 10,
          field_type: 'text',
          metadata: {
            crm_mapping: {
              hubspot: {
                type: 'existing',
                object_type: 'company',
                property_name: 'domain',
              },
            },
          },
        },
        index: 0,
      },
    ]);

    expect(draft['id:10'].hubspot.property_name).toBe('company::domain');
    expect(getCrmMappingPropertyName(draft['id:10'].hubspot)).toBe('domain');
    expect(getCrmMappingSelectionValue(draft['id:10'].hubspot)).toBe('company:domain');
  });

  it('builds stable field lookups for numeric ids and draft rows', () => {
    const lookup = buildCrmMappingFieldLookup([
      {
        field: {
          id: 42,
          field_type: 'text',
          metadata: {},
        },
        index: 0,
      },
      {
        field: {
          field_type: 'text',
          metadata: {},
        },
        index: 1,
      },
    ]);

    expect(lookup['42']).toBe('id:42');
    expect(lookup['draft:1']).toBe('draft:1');
    expect(getCrmMappingFieldStateKey({ id: 42, field_type: 'text' }, 0)).toBe('id:42');
  });

  it('merges auto-mapped results without overwriting existing selections', () => {
    const currentMappings: CrmMappings = {
      'id:42': {
        hubspot: {
          type: 'existing',
          object_type: 'contact',
          property_name: 'contact::email',
        },
      },
    };

    const merged = mergeCrmAutoMappedDraft(
      currentMappings,
      {},
      {
        '42': {
          hubspot: {
            type: 'existing',
            object_type: 'contact',
            property_name: 'contact::firstname',
          },
        },
      },
      {
        '42': 'id:42',
      },
    );

    expect(merged.mappings['id:42'].hubspot.property_name).toBe('contact::email');
    expect(merged.exportKeyOverrides['id:42']).toBeUndefined();
  });

  it('returns an immutable no-op when there are no AI suggestions', () => {
    const mappings: CrmMappings = {
      'id:42': {
        hubspot: {
          type: 'existing',
          object_type: 'contact',
          property_name: 'contact::email',
        },
      },
    };
    const exportKeyOverrides = { 'id:42': 'email' };

    const merged = mergeAiSuggestionsDraft(mappings, exportKeyOverrides, {}, 'hubspot', { '42': 'id:42' });

    expect(merged).toEqual({
      mappings,
      exportKeyOverrides,
      optionsOverrides: {},
    });
    expect(merged.mappings).not.toBe(mappings);
    expect(merged.exportKeyOverrides).not.toBe(exportKeyOverrides);
  });

  it('merges AI suggestions immutably and aligns export keys', () => {
    const mappings: CrmMappings = {};
    const exportKeyOverrides = {};

    const merged = mergeAiSuggestionsDraft(
      mappings,
      exportKeyOverrides,
      {
        '42': {
          object_type: 'company',
          property_name: 'name',
          confidence: 'high',
          reason: 'Company label strongly matches name',
        },
      },
      'hubspot',
      { '42': 'id:42' },
    );

    expect(merged.mappings).not.toBe(mappings);
    expect(merged.exportKeyOverrides).not.toBe(exportKeyOverrides);
    expect(merged.mappings['id:42'].hubspot).toEqual({
      type: 'existing',
      object_type: 'company',
      property_name: 'company::name',
    });
    expect(merged.exportKeyOverrides['id:42']).toBe('name');
  });

  it('does not overwrite an existing manual mapping with an AI suggestion', () => {
    const mappings: CrmMappings = {
      'id:42': {
        hubspot: {
          type: 'existing',
          object_type: 'contact',
          property_name: 'contact::email',
        },
      },
    };

    const merged = mergeAiSuggestionsDraft(
      mappings,
      {},
      {
        '42': {
          object_type: 'company',
          property_name: 'name',
          confidence: 'medium',
        },
      },
      'hubspot',
      { '42': 'id:42' },
    );

    expect(merged.mappings['id:42'].hubspot.property_name).toBe('contact::email');
    expect(merged.exportKeyOverrides['id:42']).toBeUndefined();
  });

  it('counts only writable CRM properties that are still available for AI suggestions', () => {
    const mappings: CrmMappings = {
      'id:42': {
        hubspot: {
          type: 'existing',
          object_type: 'contact',
          property_name: 'contact::email',
        },
      },
    };

    const count = countAvailableWritableCrmProperties(
      {
        contact: [
          { name: 'email', read_only: false },
          { name: 'firstname', read_only: false },
          { name: 'lifecycle_stage', read_only: true },
          { name: '', read_only: false },
        ],
        company: [
          { name: 'name', read_only: false },
        ],
      },
      mappings,
      'hubspot',
    );

    expect(count).toBe(2);
  });

  it('returns zero when all writable CRM properties are already mapped', () => {
    const mappings: CrmMappings = {
      'id:42': {
        hubspot: {
          type: 'existing',
          object_type: 'contact',
          property_name: 'contact::email',
        },
      },
      'id:43': {
        hubspot: {
          type: 'existing',
          object_type: 'company',
          property_name: 'company::name',
        },
      },
    };

    const count = countAvailableWritableCrmProperties(
      {
        contact: [
          { name: 'email', read_only: false },
        ],
        company: [
          { name: 'name', read_only: false },
        ],
      },
      mappings,
      'hubspot',
    );

    expect(count).toBe(0);
  });

  it('skips custom-only AI suggestions that do not target an existing property', () => {
    const merged = mergeAiSuggestionsDraft(
      {},
      {},
      {
        '42': {
          object_type: 'company',
          property_name: null,
          confidence: 'medium',
          suggest_custom: true,
          suggested_custom_name: 'registration_number',
        },
      },
      'hubspot',
      { '42': 'id:42' },
    );

    expect(merged.mappings['id:42']).toBeUndefined();
    expect(merged.exportKeyOverrides['id:42']).toBeUndefined();
  });

  it('serializes the draft back onto field metadata', () => {
    const selection = applyCrmMappingSelection(
      {},
      'id:42',
      'hubspot',
      'contact:email',
      {
        contact: [
          { name: 'email', read_only: true },
        ],
      },
    );
    const alignedKeys = applyCrmExportKeyAlignment({}, 'id:42', selection['id:42'].hubspot);
    const syncedOptions = applyCrmOptionsSync({}, 'id:42', [
      { label: 'One', value: '1' },
      { label: 'Two', value: '2' },
    ]);
    const updated = serializeCrmMappingFields(
      [
        {
          id: 42,
          field_type: 'text',
          label: 'Email',
          required: false,
          position: 1,
          metadata: {},
        },
      ],
      selection,
      alignedKeys,
      syncedOptions,
    );

    expect(updated[0].metadata!.crm_mapping?.hubspot.property_name).toBe('contact::email');
    expect(updated[0].metadata!.export_key).toBe('email');
    expect(updated[0].metadata!.options).toEqual(['One', 'Two']);
    expect(selection['id:42'].hubspot.read_only).toBe(true);
  });
});
