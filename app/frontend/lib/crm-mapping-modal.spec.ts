import { describe, expect, it } from 'vitest';
import {
  aiSuggestionMatchesCrmMapping,
  applyCrmExportKeyAlignment,
  applyCrmMappingSelection,
  applyCrmOptionsSync,
  buildAiAutoMapRequest,
  buildAiLoadingFieldKeySets,
  buildCrmMappingFieldLookup,
  buildCrmUnmappedCounts,
  countCrmValidationIssuesForProvider,
  countAvailableWritableCrmProperties,
  filterCrmProperties,
  getAiAutoMapErrorMessage,
  getCrmMappingFieldStateKey,
  getCrmMappingPropertyName,
  getCrmMappingSelectionValue,
  groupCrmValidationIssues,
  hasCrmOptionsMismatch,
  hydrateCrmMappingDraft,
  mergeAiSuggestionsDraft,
  mergeCrmAutoMappedDraft,
  normalizeAiSuggestions,
  resolveDuplicateCrmExportKeys,
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

  it('keeps pseudo file action suggestions out of export key alignment', () => {
    const merged = mergeAiSuggestionsDraft(
      {},
      {},
      {
        '42': {
          object_type: 'company',
          property_name: '__note_attachment__',
          confidence: 'high',
          reason: 'Company documents should attach to the company timeline',
        },
      },
      'hubspot',
      { '42': 'id:42' },
    );

    expect(merged.mappings['id:42'].hubspot).toEqual({
      type: 'existing',
      object_type: 'company',
      property_name: 'company::__note_attachment__',
    });
    expect(merged.exportKeyOverrides['id:42']).toBeUndefined();

    const alignedKeys = applyCrmExportKeyAlignment({}, 'id:42', merged.mappings['id:42'].hubspot);

    expect(alignedKeys).toEqual({});
  });

  it('merges custom-only AI suggestions into custom CRM mappings', () => {
    const merged = mergeAiSuggestionsDraft(
      {},
      {},
      {
        '42': {
          object_type: 'company',
          property_name: null,
          confidence: 'medium',
          suggest_custom: true,
          suggested_custom_name: 'legal_name',
        },
      },
      'hubspot',
      { '42': 'id:42' },
    );

    expect(merged.mappings['id:42'].hubspot).toEqual({
      type: 'custom',
      object_type: 'company',
      property_name: 'company::legal_name',
    });
    expect(merged.exportKeyOverrides['id:42']).toBe('legal_name');
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

  it('filters CRM properties by search and sorts compatible properties first', () => {
    const properties = filterCrmProperties(
      [
        { name: 'age', label: 'Age', type: 'number' },
        { name: 'account_age', label: 'Account Age', type: 'string' },
        { name: 'city', label: 'City', type: 'string' },
      ],
      'age',
      { field_type: 'number', metadata: {} },
      'salesforce',
    );

    expect(properties.map((property) => property.name)).toEqual(['age', 'account_age']);
  });

  it('builds the AI auto-map request payload from unmapped fields and existing mappings', () => {
    const request = buildAiAutoMapRequest(
      [
        {
          field: {
            id: 'field-1',
            field_type: 'text',
            label: 'Email',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'contact',
                  property_name: 'email',
                },
              },
            },
          },
          index: 0,
        },
        {
          field: {
            id: 'field-2',
            field_type: 'text',
            label: 'Company Name',
            required: true,
            position: 2,
            metadata: {
              options: ['Acme'],
              allow_multiple: false,
            },
          },
          index: 1,
        },
        {
          field: {
            id: 'section-1',
            field_type: 'section',
            label: 'Business Details',
            metadata: {},
          },
          index: 2,
        },
      ],
      hydrateCrmMappingDraft([
        {
          field: {
            id: 'field-1',
            field_type: 'text',
            label: 'Email',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'contact',
                  property_name: 'email',
                },
              },
            },
          },
          index: 0,
        },
        {
          field: {
            id: 'field-2',
            field_type: 'text',
            label: 'Company Name',
            required: true,
            position: 2,
            metadata: {
              options: ['Acme'],
              allow_multiple: false,
            },
          },
          index: 1,
        },
        {
          field: {
            id: 'section-1',
            field_type: 'section',
            label: 'Business Details',
            metadata: {},
          },
          index: 2,
        },
      ]),
      'hubspot',
      {
        'field-1': 'id:field-1',
        'field-2': 'id:field-2',
      },
    );

    expect(request.unmappedFields).toEqual([
      {
        id: 'field-2',
        label: 'Company Name',
        field_type: 'text',
        required: true,
        position: 2,
        metadata: {
          options: ['Acme'],
          allow_multiple: false,
        },
      },
    ]);
    expect(request.alreadyMapped).toEqual(['contact::email']);
    expect(request.pendingFieldKeys).toEqual(['id:field-2']);
    expect(request.draftFields).toEqual([
      {
        id: 'field-2',
        label: 'Company Name',
        field_type: 'text',
        required: true,
        position: 2,
        metadata: {
          options: ['Acme'],
          allow_multiple: false,
        },
      },
      {
        id: 'section-1',
        label: 'Business Details',
        field_type: 'section',
        required: false,
        position: 3,
      },
    ]);
    expect(request.totalUnmappedCount).toBe(1);
    expect(request.allUnmappedFieldIds).toEqual(['field-2']);
  });

  it('excludes custom mappings from the already-mapped AI request payload', () => {
    const request = buildAiAutoMapRequest(
      [
        {
          field: {
            id: 'field-1',
            field_type: 'text',
            label: 'Legal Name',
            metadata: {},
          },
          index: 0,
        },
      ],
      {
        'id:field-1': {
          hubspot: {
            type: 'custom',
            object_type: 'company',
            property_name: 'company::legal_name',
          },
        },
      },
      'hubspot',
      { 'field-1': 'id:field-1' },
    );

    expect(request.alreadyMapped).toEqual([]);
    expect(request.totalUnmappedCount).toBe(0);
    expect(request.allUnmappedFieldIds).toEqual([]);
  });

  it('excludes pseudo file actions from the already-mapped AI request payload', () => {
    const request = buildAiAutoMapRequest(
      [
        {
          field: {
            id: 'field-1',
            field_type: 'file',
            label: 'Certificate of Incorporation',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'company',
                  property_name: '__note_attachment__',
                },
              },
            },
          },
          index: 0,
        },
        {
          field: {
            id: 'field-2',
            field_type: 'file',
            label: 'Proof of Address',
            metadata: {},
          },
          index: 1,
        },
      ],
      hydrateCrmMappingDraft([
        {
          field: {
            id: 'field-1',
            field_type: 'file',
            label: 'Certificate of Incorporation',
            metadata: {
              crm_mapping: {
                hubspot: {
                  type: 'existing',
                  object_type: 'company',
                  property_name: '__note_attachment__',
                },
              },
            },
          },
          index: 0,
        },
        {
          field: {
            id: 'field-2',
            field_type: 'file',
            label: 'Proof of Address',
            metadata: {},
          },
          index: 1,
        },
      ]),
      'hubspot',
      {
        'field-1': 'id:field-1',
        'field-2': 'id:field-2',
      },
    );

    expect(request.alreadyMapped).toEqual([]);
    expect(request.unmappedFields.map((field) => field.id)).toEqual(['field-2']);
  });

  it('limits AI requests to a smaller batch while preserving layout context in original order', () => {
    const request = buildAiAutoMapRequest(
      [
        {
          field: {
            id: 'section-1',
            field_type: 'section',
            label: 'Business Details',
            metadata: {},
          },
          index: 0,
        },
        {
          field: {
            id: 'field-1',
            field_type: 'text',
            label: 'Legal Name',
            metadata: {},
          },
          index: 1,
        },
        {
          field: {
            id: 'field-2',
            field_type: 'text',
            label: 'Registration Number',
            metadata: {},
          },
          index: 2,
        },
        {
          field: {
            id: 'field-3',
            field_type: 'text',
            label: 'Website',
            metadata: {},
          },
          index: 3,
        },
      ],
      hydrateCrmMappingDraft([
        {
          field: {
            id: 'section-1',
            field_type: 'section',
            label: 'Business Details',
            metadata: {},
          },
          index: 0,
        },
        {
          field: {
            id: 'field-1',
            field_type: 'text',
            label: 'Legal Name',
            metadata: {},
          },
          index: 1,
        },
        {
          field: {
            id: 'field-2',
            field_type: 'text',
            label: 'Registration Number',
            metadata: {},
          },
          index: 2,
        },
        {
          field: {
            id: 'field-3',
            field_type: 'text',
            label: 'Website',
            metadata: {},
          },
          index: 3,
        },
      ]),
      'hubspot',
      {
        'field-1': 'id:field-1',
        'field-2': 'id:field-2',
        'field-3': 'id:field-3',
      },
      { batchSize: 2 },
    );

    expect(request.unmappedFields.map((field) => field.id)).toEqual(['field-1', 'field-2']);
    expect(request.draftFields.map((field) => field.id)).toEqual(['section-1', 'field-1', 'field-2']);
    expect(request.totalUnmappedCount).toBe(3);
    expect(request.allUnmappedFieldIds).toEqual(['field-1', 'field-2', 'field-3']);
  });

  it('builds a targeted AI batch for specific remaining field ids', () => {
    const request = buildAiAutoMapRequest(
      [
        {
          field: {
            id: 'section-1',
            field_type: 'section',
            label: 'Business Details',
            metadata: {},
          },
          index: 0,
        },
        {
          field: {
            id: 'field-1',
            field_type: 'text',
            label: 'Legal Name',
            metadata: {},
          },
          index: 1,
        },
        {
          field: {
            id: 'field-2',
            field_type: 'text',
            label: 'Registration Number',
            metadata: {},
          },
          index: 2,
        },
      ],
      {},
      'hubspot',
      {
        'field-1': 'id:field-1',
        'field-2': 'id:field-2',
      },
      { fieldIds: ['field-2'] },
    );

    expect(request.unmappedFields.map((field) => field.id)).toEqual(['field-2']);
    expect(request.pendingFieldKeys).toEqual(['id:field-2']);
    expect(request.draftFields.map((field) => field.id)).toEqual(['section-1', 'field-2']);
    expect(request.totalUnmappedCount).toBe(2);
    expect(request.allUnmappedFieldIds).toEqual(['field-1', 'field-2']);
  });

  it('builds provider unmapped counts and AI loading key sets', () => {
    const mappings: CrmMappings = {
      'id:42': {
        hubspot: {
          type: 'existing',
          object_type: 'contact',
          property_name: 'contact::email',
        },
      },
      'id:43': {},
    };

    const counts = buildCrmUnmappedCounts(
      ['hubspot'],
      [
        {
          field: { id: 42, field_type: 'text', metadata: {} },
          index: 0,
        },
        {
          field: { id: 43, field_type: 'text', metadata: {} },
          index: 1,
        },
      ],
      mappings,
    );

    expect(counts).toEqual({ hubspot: 1 });
    expect(buildAiLoadingFieldKeySets({ hubspot: ['id:43'] }).hubspot.has('id:43')).toBe(true);
  });

  it('normalizes AI suggestions, matches mappings, and maps AI errors to UI messages', () => {
    const normalized = normalizeAiSuggestions(
      {
        '42': {
          object_type: 'contact',
          property_name: 'email',
          confidence: 'high',
        },
      },
      { '42': 'id:42' },
    );

    expect(normalized['id:42']).toEqual({
      object_type: 'contact',
      property_name: 'email',
      confidence: 'high',
    });
    expect(aiSuggestionMatchesCrmMapping(
      {
        type: 'existing',
        object_type: 'contact',
        property_name: 'contact::email',
      },
      normalized['id:42'],
    )).toBe(true);
    expect(aiSuggestionMatchesCrmMapping(
      {
        type: 'custom',
        object_type: 'company',
        property_name: 'company::legal_name',
      },
      {
        object_type: 'company',
        property_name: null,
        confidence: 'medium',
        suggest_custom: true,
        suggested_custom_name: 'legal_name',
      },
    )).toBe(true);
    expect(getAiAutoMapErrorMessage('unknown_error')).toBe('AI auto-map failed. Please try again.');
  });

  it('detects CRM option mismatches case-insensitively', () => {
    expect(hasCrmOptionsMismatch(['Approved', ' Pending '], [
      { label: 'approved', value: 'approved' },
      { label: 'pending', value: 'pending' },
    ])).toBe(false);

    expect(hasCrmOptionsMismatch(['Approved', 'Rejected'], [
      { label: 'approved', value: 'approved' },
    ])).toBe(true);
  });

  it('groups live CRM validation issues by provider and field key', () => {
    const grouped = groupCrmValidationIssues([
      {
        provider: 'hubspot',
        field_key: 'id:42',
        field_id: '42',
        index: 0,
        field_label: 'Phone Number',
        object_type: 'contact',
        property_name: 'phone_number',
        code: 'missing_property',
        message: 'Missing property',
      },
      {
        provider: 'hubspot',
        field_key: 'id:42',
        field_id: '42',
        index: 0,
        field_label: 'Phone Number',
        object_type: 'contact',
        property_name: 'phone_number',
        code: 'option_mismatch',
        message: 'Invalid option',
        invalid_options: ['Online'],
        allowed_options: ['storefront'],
      },
      {
        provider: 'salesforce',
        field_key: 'draft:1',
        index: 1,
        field_label: 'Industry',
        object_type: 'company',
        property_name: 'Industry',
        code: 'missing_property',
        message: 'Missing property',
      },
    ]);

    expect(grouped.hubspot['id:42']).toHaveLength(2);
    expect(grouped.salesforce['draft:1']).toHaveLength(1);
    expect(countCrmValidationIssuesForProvider(grouped, 'hubspot')).toBe(2);
  });

  it('skips custom-only AI suggestions that do not target an existing property', () => {
    const resolved = resolveDuplicateCrmExportKeys([
      {
        id: 'section-1',
        label: 'KYC',
        field_type: 'section',
        required: false,
        position: 1,
        metadata: {},
      },
      {
        id: 'field-1',
        label: 'Phone Number',
        field_type: 'text',
        required: false,
        position: 2,
        metadata: {
          export_key: 'phone_number',
          crm_mapping: {
            hubspot: {
              type: 'existing',
              object_type: 'contact',
              property_name: 'contact::phone',
            },
          },
        },
      },
      {
        id: 'section-2',
        label: 'KYB',
        field_type: 'section',
        required: false,
        position: 3,
        metadata: {},
      },
      {
        id: 'field-2',
        label: 'Phone Number',
        field_type: 'text',
        required: false,
        position: 4,
        metadata: {
          export_key: 'phone_number',
          crm_mapping: {
            hubspot: {
              type: 'existing',
              object_type: 'contact',
              property_name: 'contact::mobilephone',
            },
          },
        },
      },
    ]);

    expect(resolved[1].metadata!.export_key).toBe('phone_number_kyc');
    expect(resolved[3].metadata!.export_key).toBe('phone_number_kyb');
  });

  it('falls back to numeric suffixes when duplicate CRM export keys stay in the same section scope', () => {
    const resolved = resolveDuplicateCrmExportKeys([
      {
        id: 'section-1',
        label: 'KYC',
        field_type: 'section',
        required: false,
        position: 1,
        metadata: {},
      },
      {
        id: 'field-1',
        label: 'Phone Number',
        field_type: 'text',
        required: false,
        position: 2,
        metadata: {
          export_key: 'phone_number',
          crm_mapping: {
            hubspot: {
              type: 'custom',
              object_type: 'contact',
              property_name: 'contact::phone_number',
            },
          },
        },
      },
      {
        id: 'field-2',
        label: 'Phone Number',
        field_type: 'text',
        required: false,
        position: 3,
        metadata: {
          export_key: 'phone_number',
          crm_mapping: {
            hubspot: {
              type: 'custom',
              object_type: 'contact',
              property_name: 'contact::phone_number_secondary',
            },
          },
        },
      },
    ]);

    expect(resolved[1].metadata!.export_key).toBe('phone_number_kyc');
    expect(resolved[2].metadata!.export_key).toBe('phone_number_kyc_2');
  });

  it('keeps same export keys across different CRM object scopes', () => {
    const resolved = resolveDuplicateCrmExportKeys([
      {
        id: 'field-1',
        label: 'Name',
        field_type: 'text',
        required: false,
        position: 1,
        metadata: {
          export_key: 'name',
          crm_mapping: {
            hubspot: {
              type: 'existing',
              object_type: 'contact',
              property_name: 'contact::firstname',
            },
          },
        },
      },
      {
        id: 'field-2',
        label: 'Name',
        field_type: 'text',
        required: false,
        position: 2,
        metadata: {
          export_key: 'name',
          crm_mapping: {
            hubspot: {
              type: 'existing',
              object_type: 'company',
              property_name: 'company::name',
            },
          },
        },
      },
    ]);

    expect(resolved[0].metadata!.export_key).toBe('name');
    expect(resolved[1].metadata!.export_key).toBe('name');
  });

  it('serializes custom-only AI suggestions into a stable custom export key', () => {
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

    expect(merged.mappings['id:42'].hubspot).toEqual({
      type: 'custom',
      object_type: 'company',
      property_name: 'company::registration_number',
    });
    expect(merged.exportKeyOverrides['id:42']).toBe('registration_number');
  });

  it('deduplicates custom AI property names within the same provider scope', () => {
    const merged = mergeAiSuggestionsDraft(
      {
        'id:41': {
          hubspot: {
            type: 'custom',
            object_type: 'company',
            property_name: 'company::registration_number',
          },
        },
      },
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

    expect(merged.mappings['id:42'].hubspot.property_name).toBe('company::registration_number_2');
    expect(merged.exportKeyOverrides['id:42']).toBe('registration_number_2');
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

  it('assigns a usable default property name when a manual custom mapping is selected', () => {
    const selection = applyCrmMappingSelection(
      {},
      'id:42',
      'hubspot',
      '__custom_company__',
      {},
      {
        id: 42,
        field_type: 'text',
        label: 'Registration Number',
        metadata: {},
      },
      0,
    );

    expect(selection['id:42'].hubspot).toEqual({
      type: 'custom',
      object_type: 'company',
      property_name: 'company::registration_number',
    });
  });
});
