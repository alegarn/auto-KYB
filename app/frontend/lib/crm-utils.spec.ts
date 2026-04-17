import { describe, it, expect } from 'vitest';
import { areTypesCompatible, getCrmObjectLabel, getFieldDataType, analyzeMappings, autoMapFields, toCrmKey, fromCrmKey, isCompoundKey, getFieldIdentityKey } from './crm-utils';

describe('getFieldDataType', () => {
  it('identifies string types', () => {
    expect(getFieldDataType('text')).toBe('string');
    expect(getFieldDataType('email')).toBe('string');
  });

  it('identifies choice types', () => {
    expect(getFieldDataType('select')).toBe('single_choice');
    expect(getFieldDataType('radio')).toBe('single_choice');
    expect(getFieldDataType({ field_type: 'checkbox' })).toBe('single_choice');
    expect(getFieldDataType({ field_type: 'checkbox', metadata: { allow_multiple: true } })).toBe('multi_choice');
    expect(getFieldDataType({ field_type: 'buttons' })).toBe('single_choice');
    expect(getFieldDataType({ field_type: 'buttons', metadata: { allow_multiple: true } })).toBe('multi_choice');
  });

  it('identifies number types', () => {
    expect(getFieldDataType('number')).toBe('number');
  });

  it('identifies date types', () => {
    expect(getFieldDataType('date')).toBe('date');
  });
});

describe('getFieldIdentityKey', () => {
  it('returns the raw id when one exists and a draft key otherwise', () => {
    expect(getFieldIdentityKey({ id: 42 }, 0)).toBe('42');
    expect(getFieldIdentityKey({ id: 'abc' }, 1)).toBe('abc');
    expect(getFieldIdentityKey({}, 2)).toBe('draft:2');
  });
});

describe('getCrmObjectLabel', () => {
  it('returns provider-specific labels for supported CRM objects', () => {
    expect(getCrmObjectLabel('hubspot', 'company')).toBe('Company');
    expect(getCrmObjectLabel('salesforce', 'company')).toBe('Account');
    expect(getCrmObjectLabel('zoho', 'company')).toBe('Account');
    expect(getCrmObjectLabel('hubspot', 'contact')).toBe('Contact');
  });

  it('falls back to a capitalized object type when no provider-specific label exists', () => {
    expect(getCrmObjectLabel('unknown', 'deal')).toBe('Deal');
    expect(getCrmObjectLabel('hubspot', '')).toBe('Record');
  });
});

describe('areTypesCompatible', () => {
  it('returns true if either type is missing', () => {
    expect(areTypesCompatible('', 'string')).toBe(true);
    expect(areTypesCompatible('text', '')).toBe(true);
  });

  it('returns true for exact data type matches', () => {
    expect(areTypesCompatible('text', 'string')).toBe(true);
    expect(areTypesCompatible('number', 'number')).toBe(true);
  });

  it('returns true for compatible enumeration types (generic — no sub-type discrimination)', () => {
    expect(areTypesCompatible('select', 'enumeration')).toBe(true);
    expect(areTypesCompatible({ field_type: 'checkbox' }, 'enumeration')).toBe(true);
    // multi_choice is generically compatible with enumeration (sub-type check lives in hubspot-compat)
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: true } }, 'enumeration')).toBe(true);
  });

  it('ignores the optional crmFieldType parameter — HubSpot-specific sub-type logic lives in crm/hubspot-compat', () => {
    // areTypesCompatible no longer enforces checkbox vs select/radio distinction
    expect(areTypesCompatible({ field_type: 'select' }, 'enumeration', 'select')).toBe(true);
    expect(areTypesCompatible({ field_type: 'select' }, 'enumeration', 'booleancheckbox')).toBe(true);
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: true } }, 'enumeration', 'radio')).toBe(true);
  });

  it('returns false for text→enumeration mapping (string not in enumeration compat list)', () => {
    expect(areTypesCompatible('text', 'enumeration')).toBe(false);
    expect(areTypesCompatible('email', 'enumeration')).toBe(false);
  });

  it('returns false for incompatible data types', () => {
    expect(areTypesCompatible('number', 'boolean')).toBe(false);
    expect(areTypesCompatible('date', 'number')).toBe(false);
  });
});

describe('analyzeMappings', () => {
  it('returns none status when no mappings exist', () => {
    const result = analyzeMappings({}, 'hubspot');

    expect(result.contact.status).toBe('none');
    expect(result.contact.count).toBe(0);
    expect(result.company.status).toBe('none');
    expect(result.company.count).toBe(0);
    expect(result.association.status).toBe('none');
  });

  it('returns ready status for contact when fields mapped', () => {
    const mappings = {
      field_1: { hubspot: { object_type: 'contact', property_name: 'contact::firstname' } },
      field_2: { hubspot: { object_type: 'contact', property_name: 'contact::email' } }
    };
    const result = analyzeMappings(mappings, 'hubspot');

    expect(result.contact.status).toBe('ready');
    expect(result.contact.count).toBe(2);
    expect(result.company.status).toBe('none');
    expect(result.association.status).toBe('none');
  });

  it('returns warning status for company when missing identifiers', () => {
    const mappings = {
      field_1: { hubspot: { object_type: 'company', property_name: 'company::city' } }
    };
    const result = analyzeMappings(mappings, 'hubspot');

    expect(result.company.status).toBe('warning');
    expect(result.company.count).toBe(1);
    expect(result.company.missingIdentifiers).toEqual(['name', 'domain']);
    expect(result.contact.status).toBe('none');
  });

  it('returns ready status for company when identifier is present (compound key)', () => {
    const mappings = {
      field_1: { hubspot: { object_type: 'company', property_name: 'company::domain' } }
    };
    const result = analyzeMappings(mappings, 'hubspot');

    expect(result.company.status).toBe('ready');
    expect(result.company.count).toBe(1);
    expect(result.company.missingIdentifiers).toBeUndefined();
  });

  it('handles legacy property_name without compound prefix', () => {
    const mappings = {
      field_1: { hubspot: { object_type: 'company', property_name: 'domain' } }
    };
    const result = analyzeMappings(mappings, 'hubspot');

    // Legacy key 'domain' is parsed as contact by fromCrmKey, but still matches 'domain' identifier
    expect(result.company.status).toBe('ready');
    expect(result.company.count).toBe(1);
  });

  it('verifies association status based on both components', () => {
    const readyCompanyMappings = {
      field_1: { hubspot: { object_type: 'contact', property_name: 'contact::email' } },
      field_2: { hubspot: { object_type: 'company', property_name: 'company::name' } }
    };
    const readyResult = analyzeMappings(readyCompanyMappings, 'hubspot');
    expect(readyResult.association.status).toBe('ready');

    const warningCompanyMappings = {
      field_1: { hubspot: { object_type: 'contact', property_name: 'contact::email' } },
      field_2: { hubspot: { object_type: 'company', property_name: 'company::city' } }
    };
    const warningResult = analyzeMappings(warningCompanyMappings, 'hubspot');
    expect(warningResult.association.status).toBe('warning');
  });
});

describe('autoMapFields', () => {
  const mockProperties = {
    hubspot: {
      contact: [
        { name: 'firstname', label: 'First Name', type: 'string' },
        { name: 'email', label: 'Email', type: 'string' },
        { name: 'phone', label: 'Phone Number', type: 'string' }
      ],
      company: [
        { name: 'name', label: 'Company Name', type: 'string' },
        { name: 'domain', label: 'Company Domain', type: 'string' }
      ]
    }
  };

  it('matches by field label and returns compound key', () => {
    const fields = [{ id: '1', label: 'First Name', field_type: 'text', metadata: {} }];
    const result = autoMapFields(fields, mockProperties);
    
    expect(result['1'].hubspot).toBeDefined();
    expect(result['1'].hubspot.property_name).toBe('contact::firstname');
    expect(result['1'].hubspot.object_type).toBe('contact');
  });

  it('maps draft fields without ids using a stable fallback key', () => {
    const fields = [{ label: 'Company name', field_type: 'text', metadata: {} }];
    const result = autoMapFields(fields, mockProperties);

    expect(result['draft:0'].hubspot).toBeDefined();
    expect(result['draft:0'].hubspot.property_name).toBe('company::name');
    expect(result['draft:0'].hubspot.object_type).toBe('company');
  });

  it('maps persisted numeric ids using the shared state key format', () => {
    const fields = [{ id: 42, label: 'First Name', field_type: 'text', metadata: {} }];
    const result = autoMapFields(fields, mockProperties);

    expect(result['42'].hubspot.property_name).toBe('contact::firstname');
  });

  it('ignores layout fields during legacy auto-map', () => {
    const fields = [
      { id: 'section-1', label: 'Identity', field_type: 'section', metadata: {} },
      { id: 'field-1', label: 'Email', field_type: 'text', metadata: {} },
    ];
    const result = autoMapFields(fields, mockProperties);

    expect(result['section-1']).toBeUndefined();
    expect(result['field-1'].hubspot.property_name).toBe('contact::email');
  });

  it('maps company name fields to the company name property even when the CRM label is generic', () => {
    const fields = [{ id: '1', label: 'Company name', field_type: 'text', metadata: {} }];
    const genericCompanyProps = {
      hubspot: {
        contact: [
          { name: 'associatedcompanyname', label: 'Associated company name', type: 'string' }
        ],
        company: [
          { name: 'name', label: 'Name', type: 'string' }
        ]
      }
    };

    const result = autoMapFields(fields, genericCompanyProps);

    expect(result['1'].hubspot.property_name).toBe('company::name');
    expect(result['1'].hubspot.object_type).toBe('company');
  });

  it('uses company-oriented export keys to disambiguate fuzzy matches', () => {
    const fields = [{
      id: '1',
      label: 'Business',
      field_type: 'text',
      metadata: { export_key: 'company_name' } as any
    }];
    const genericCompanyProps = {
      hubspot: {
        contact: [
          { name: 'associatedcompanyname', label: 'Associated company name', type: 'string' }
        ],
        company: [
          { name: 'name', label: 'Name', type: 'string' }
        ]
      }
    };

    const result = autoMapFields(fields, genericCompanyProps);

    expect(result['1'].hubspot.property_name).toBe('company::name');
    expect(result['1'].hubspot.object_type).toBe('company');
  });

  it('prioritizes export_key even when label differs', () => {
    const fields = [{ 
      id: '1', 
      label: 'Your Mobile', 
      field_type: 'text', 
      metadata: { export_key: 'phone' } as any
    }];
    const result = autoMapFields(fields, mockProperties);
    
    expect(result['1'].hubspot).toBeDefined();
    expect(result['1'].hubspot.property_name).toBe('contact::phone');
  });

  it('handles multi-CRM by picking first match for each provider', () => {
    const multiCrmProps = {
      ...mockProperties,
      salesforce: {
        contact: [{ name: 'FirstName', label: 'First Name', type: 'string' }],
        company: []
      }
    };
    const fields = [{ id: '1', label: 'First Name', field_type: 'text', metadata: {} }];
    const result = autoMapFields(fields, multiCrmProps);
    
    expect(result['1'].hubspot.property_name).toBe('contact::firstname');
    expect(result['1'].salesforce.property_name).toBe('contact::FirstName');
  });

  it('skips incompatible types', () => {
    const fields = [{ 
      id: '1', 
      label: 'Email', 
      field_type: 'number',
      metadata: {} 
    }];
    const result = autoMapFields(fields, mockProperties);
    
    expect(result['1'].hubspot).toBeUndefined();
  });

  it('disambiguates same property across contact and company', () => {
    const propsWithSameKey = {
      hubspot: {
        contact: [
          { name: 'address', label: 'Street Address', type: 'string' }
        ],
        company: [
          { name: 'address', label: 'Street Address', type: 'string' }
        ]
      }
    };
    
    // First match wins (contact), but the compound key carries the object_type
    const fields = [{ id: '1', label: 'Street Address', field_type: 'text', metadata: {} }];
    const result = autoMapFields(fields, propsWithSameKey);
    
    expect(result['1'].hubspot.property_name).toContain('::address');
    expect(result['1'].hubspot.object_type).toBeDefined();
    // Compound key always includes the chosen object_type
    const parsed = fromCrmKey(result['1'].hubspot.property_name);
    expect(parsed.propertyName).toBe('address');
    expect(parsed.objectType).toBe(result['1'].hubspot.object_type);
  });

  it('prefers company properties for address-like fields when both objects expose the same key', () => {
    const propsWithSameKey = {
      hubspot: {
        contact: [
          { name: 'address', label: 'Street Address', type: 'string' }
        ],
        company: [
          { name: 'address', label: 'Street Address', type: 'string' }
        ]
      }
    };

    const fields = [{ id: '1', label: 'Street Address', field_type: 'text', metadata: {} }];
    const result = autoMapFields(fields, propsWithSameKey);

    expect(result['1'].hubspot.property_name).toBe('company::address');
    expect(result['1'].hubspot.object_type).toBe('company');
  });
});

describe('toCrmKey / fromCrmKey', () => {
  it('builds a compound key from object_type and property_name', () => {
    expect(toCrmKey('company', 'address')).toBe('company::address');
    expect(toCrmKey('contact', 'email')).toBe('contact::email');
  });

  it('returns empty string if property_name is empty', () => {
    expect(toCrmKey('company', '')).toBe('');
  });

  it('returns property_name if object_type is empty', () => {
    expect(toCrmKey('', 'address')).toBe('address');
  });

  it('parses a compound key correctly', () => {
    const result = fromCrmKey('company::address');
    expect(result.objectType).toBe('company');
    expect(result.propertyName).toBe('address');
  });

  it('defaults to contact for legacy keys without separator', () => {
    const result = fromCrmKey('email');
    expect(result.objectType).toBe('contact');
    expect(result.propertyName).toBe('email');
  });

  it('handles null/undefined', () => {
    expect(fromCrmKey(null).objectType).toBe('contact');
    expect(fromCrmKey(null).propertyName).toBe('');
    expect(fromCrmKey(undefined).objectType).toBe('contact');
    expect(fromCrmKey(undefined).propertyName).toBe('');
  });

  it('preserves property names with colons', () => {
    const result = fromCrmKey('contact::some:special:name');
    expect(result.objectType).toBe('contact');
    expect(result.propertyName).toBe('some:special:name');
  });
});

describe('isCompoundKey', () => {
  it('returns true for compound keys', () => {
    expect(isCompoundKey('company::address')).toBe(true);
  });

  it('returns false for legacy keys', () => {
    expect(isCompoundKey('address')).toBe(false);
  });

  it('returns false for null/undefined', () => {
    expect(isCompoundKey(null)).toBe(false);
    expect(isCompoundKey(undefined)).toBe(false);
  });
});

// ── HubSpot Enumeration Mapping User Stories ─────────────────────────────────

describe('US-01: dropdown (select) — generic enum compat (sub-type gating is in hubspot-compat)', () => {
  it('select → enumeration is generically compatible regardless of field_type arg', () => {
    expect(areTypesCompatible({ field_type: 'select' }, 'enumeration')).toBe(true);
    expect(areTypesCompatible({ field_type: 'select' }, 'enumeration', 'select')).toBe(true);
    expect(areTypesCompatible({ field_type: 'select' }, 'enumeration', 'radio')).toBe(true);
    // crmFieldType is now ignored — use isHubSpotCompatible for sub-type enforcement
    expect(areTypesCompatible({ field_type: 'select' }, 'enumeration', 'checkbox')).toBe(true);
  });
});

describe('US-02: radio field — generic enum compat (sub-type gating is in hubspot-compat)', () => {
  it('radio → enumeration is generically compatible regardless of field_type arg', () => {
    expect(areTypesCompatible({ field_type: 'radio' }, 'enumeration')).toBe(true);
    expect(areTypesCompatible({ field_type: 'radio' }, 'enumeration', 'radio')).toBe(true);
    expect(areTypesCompatible({ field_type: 'radio' }, 'enumeration', 'checkbox')).toBe(true);
  });
});

describe('US-03: single checkbox (allow_multiple: false) — generic enum compat', () => {
  it('getFieldDataType returns single_choice', () => {
    expect(getFieldDataType({ field_type: 'checkbox', metadata: { allow_multiple: false } })).toBe('single_choice');
  });

  it('single checkbox → enumeration is generically compatible (no sub-type enforcement)', () => {
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: false } }, 'enumeration')).toBe(true);
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: false } }, 'enumeration', 'select')).toBe(true);
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: false } }, 'enumeration', 'checkbox')).toBe(true);
  });
});

describe('US-04: multi-checkbox — generic enum compat (sub-type gating is in hubspot-compat)', () => {
  it('getFieldDataType returns multi_choice', () => {
    expect(getFieldDataType({ field_type: 'checkbox', metadata: { allow_multiple: true } })).toBe('multi_choice');
  });

  it('multi-checkbox → enumeration is generically compatible (no sub-type enforcement)', () => {
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: true } }, 'enumeration')).toBe(true);
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: true } }, 'enumeration', 'checkbox')).toBe(true);
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: true } }, 'enumeration', 'select')).toBe(true);
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: true } }, 'enumeration', 'radio')).toBe(true);
  });
});

describe('US-05: buttons field — generic enum compat', () => {
  it('multi-buttons → enumeration is generically compatible', () => {
    expect(areTypesCompatible({ field_type: 'buttons', metadata: { allow_multiple: true } }, 'enumeration')).toBe(true);
    expect(areTypesCompatible({ field_type: 'buttons', metadata: { allow_multiple: true } }, 'enumeration', 'checkbox')).toBe(true);
  });

  it('single-buttons → enumeration is generically compatible', () => {
    expect(areTypesCompatible({ field_type: 'buttons', metadata: { allow_multiple: false } }, 'enumeration')).toBe(true);
    expect(areTypesCompatible({ field_type: 'buttons', metadata: { allow_multiple: false } }, 'enumeration', 'select')).toBe(true);
    expect(areTypesCompatible({ field_type: 'buttons', metadata: { allow_multiple: false } }, 'enumeration', 'checkbox')).toBe(true);
  });
});

describe('US-06: text field CANNOT map to any enumeration property', () => {
  it('getFieldDataType returns string for text', () => {
    expect(getFieldDataType({ field_type: 'text' })).toBe('string');
  });

  it('text → enumeration/select is NOT compatible', () => {
    expect(areTypesCompatible({ field_type: 'text' }, 'enumeration', 'select')).toBe(false);
  });

  it('text → enumeration/radio is NOT compatible', () => {
    expect(areTypesCompatible({ field_type: 'text' }, 'enumeration', 'radio')).toBe(false);
  });

  it('text → enumeration/checkbox is NOT compatible', () => {
    expect(areTypesCompatible({ field_type: 'text' }, 'enumeration', 'checkbox')).toBe(false);
  });

  it('text → enumeration (no sub-type) is NOT compatible', () => {
    expect(areTypesCompatible({ field_type: 'text' }, 'enumeration')).toBe(false);
  });
});

describe('US-07: booleancheckbox — handled by hubspot-compat, not areTypesCompatible', () => {
  // areTypesCompatible is provider-agnostic; it ignores the crmFieldType parameter.
  // HubSpot-specific booleancheckbox compatibility lives in crm/hubspot-compat.ts.
  it('single_choice → enumeration is generically true (sub-type gating is HubSpot-specific)', () => {
    expect(areTypesCompatible({ field_type: 'select' }, 'enumeration', 'booleancheckbox')).toBe(true);
  });

  it('radio → enumeration is generically true regardless of crmFieldType arg', () => {
    expect(areTypesCompatible({ field_type: 'radio' }, 'enumeration', 'booleancheckbox')).toBe(true);
  });

  it('multi_choice → enumeration is generically true regardless of crmFieldType arg', () => {
    expect(areTypesCompatible({ field_type: 'checkbox', metadata: { allow_multiple: true } }, 'enumeration', 'booleancheckbox')).toBe(true);
  });
});

describe('autoMapFields with real HubSpot enumeration properties', () => {
  // Property definitions mirror the real HubSpot API shape used by the app
  const hs_lead_status = {
    name: 'hs_lead_status', label: 'Lead Status', type: 'enumeration', field_type: 'radio',
    options: [
      { label: 'New', value: 'NEW' }, { label: 'Open', value: 'OPEN' },
      { label: 'In Progress', value: 'IN_PROGRESS' }, { label: 'Open Deal', value: 'OPEN_DEAL' },
      { label: 'Unqualified', value: 'UNQUALIFIED' },
      { label: 'Attempted to Contact', value: 'ATTEMPTED_TO_CONTACT' },
      { label: 'Connected', value: 'CONNECTED' }, { label: 'Bad Timing', value: 'BAD_TIMING' },
    ],
  };

  const hs_buying_role = {
    name: 'hs_buying_role', label: 'Buying Role', type: 'enumeration', field_type: 'checkbox',
    options: [
      { label: 'Blocker', value: 'BLOCKER' }, { label: 'Budget Holder', value: 'BUDGET_HOLDER' },
      { label: 'Champion', value: 'CHAMPION' }, { label: 'Decision Maker', value: 'DECISION_MAKER' },
      { label: 'End User', value: 'END_USER' }, { label: 'Executive Sponsor', value: 'EXECUTIVE_SPONSOR' },
    ],
  };

  const hs_analytics_source = {
    name: 'hs_analytics_source', label: 'Source', type: 'enumeration', field_type: 'select',
    options: [
      { label: 'Organic Search', value: 'ORGANIC_SEARCH' }, { label: 'Paid Search', value: 'PAID_SEARCH' },
      { label: 'Email Marketing', value: 'EMAIL_MARKETING' }, { label: 'Direct Traffic', value: 'DIRECT_TRAFFIC' },
    ],
  };

  const hs_firstname = { name: 'firstname', label: 'First Name', type: 'string' };

  const enumProperties = {
    hubspot: {
      contact: [hs_lead_status, hs_buying_role, hs_analytics_source, hs_firstname],
      company: [],
    },
  };

  it('select field "Lead Status" auto-maps to hs_lead_status (enumeration/radio)', () => {
    const fields = [{ id: '1', label: 'Lead Status', field_type: 'select', metadata: {} }];
    const result = autoMapFields(fields, enumProperties);

    expect(result['1'].hubspot).toBeDefined();
    expect(result['1'].hubspot.property_name).toBe('contact::hs_lead_status');
    expect(result['1'].hubspot.object_type).toBe('contact');
  });

  it('multi-checkbox field "Buying Role" auto-maps to hs_buying_role (enumeration/checkbox)', () => {
    const fields = [{ id: '2', label: 'Buying Role', field_type: 'checkbox', metadata: { allow_multiple: true } }];
    const result = autoMapFields(fields, enumProperties);

    expect(result['2'].hubspot).toBeDefined();
    expect(result['2'].hubspot.property_name).toBe('contact::hs_buying_role');
    expect(result['2'].hubspot.object_type).toBe('contact');
  });

  it('select field "Source" auto-maps to hs_analytics_source (enumeration/select)', () => {
    const fields = [{ id: '3', label: 'Source', field_type: 'select', metadata: {} }];
    const result = autoMapFields(fields, enumProperties);

    expect(result['3'].hubspot).toBeDefined();
    expect(result['3'].hubspot.property_name).toBe('contact::hs_analytics_source');
    expect(result['3'].hubspot.object_type).toBe('contact');
  });

  it('text field with matching label does NOT auto-map to any enumeration property', () => {
    // "Lead Status" text field: label matches hs_lead_status but type is incompatible
    const fields = [{ id: '4', label: 'Lead Status', field_type: 'text', metadata: {} }];

    // Only enumeration props available — no string property with a matching label
    const enumOnlyProperties = {
      hubspot: {
        contact: [hs_lead_status, hs_buying_role, hs_analytics_source],
        company: [],
      },
    };

    const result = autoMapFields(fields, enumOnlyProperties);

    expect(result['4'].hubspot).toBeUndefined();
  });
});

