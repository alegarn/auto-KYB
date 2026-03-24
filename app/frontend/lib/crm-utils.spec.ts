import { describe, it, expect } from 'vitest';
import { areTypesCompatible, getFieldDataType, analyzeMappings, autoMapFields, toCrmKey, fromCrmKey, isCompoundKey, CRM_KEY_SEP } from './crm-utils';

describe('getFieldDataType', () => {
  it('identifies string types', () => {
    expect(getFieldDataType('text')).toBe('string');
    expect(getFieldDataType('email')).toBe('string');
    expect(getFieldDataType('buttons')).toBe('string');
    expect(getFieldDataType('select')).toBe('string');
  });

  it('identifies number types', () => {
    expect(getFieldDataType('number')).toBe('number');
  });

  it('identifies boolean types', () => {
    expect(getFieldDataType('checkbox')).toBe('boolean');
  });

  it('identifies date types', () => {
    expect(getFieldDataType('date')).toBe('date');
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
    expect(areTypesCompatible('checkbox', 'boolean')).toBe(true);
  });

  it('returns true for compatible HubSpot enumeration types', () => {
    expect(areTypesCompatible('select', 'enumeration')).toBe(true);
    expect(areTypesCompatible('checkbox', 'enumeration')).toBe(true);
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

