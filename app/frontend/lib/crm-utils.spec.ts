import { describe, it, expect } from 'vitest';
import { areTypesCompatible, getFieldDataType, analyzeMappings } from './crm-utils';

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
      field_1: { hubspot: { object_type: 'contact', property_name: 'firstname' } },
      field_2: { hubspot: { object_type: 'contact', property_name: 'email' } }
    };
    const result = analyzeMappings(mappings, 'hubspot');

    expect(result.contact.status).toBe('ready');
    expect(result.contact.count).toBe(2);
    expect(result.company.status).toBe('none');
    expect(result.association.status).toBe('none');
  });

  it('returns warning status for company when missing identifiers', () => {
    const mappings = {
      field_1: { hubspot: { object_type: 'company', property_name: 'city' } }
    };
    const result = analyzeMappings(mappings, 'hubspot');

    expect(result.company.status).toBe('warning');
    expect(result.company.count).toBe(1);
    expect(result.company.missingIdentifiers).toEqual(['name', 'domain']);
    expect(result.contact.status).toBe('none');
  });

  it('returns ready status for company when identifier is present', () => {
    const mappings = {
      field_1: { hubspot: { object_type: 'company', property_name: 'domain' } }
    };
    const result = analyzeMappings(mappings, 'hubspot');

    expect(result.company.status).toBe('ready');
    expect(result.company.count).toBe(1);
    expect(result.company.missingIdentifiers).toBeUndefined();
  });

  it('verifies association status based on both components', () => {
    const readyCompanyMappings = {
      field_1: { hubspot: { object_type: 'contact', property_name: 'email' } },
      field_2: { hubspot: { object_type: 'company', property_name: 'name' } }
    };
    const readyResult = analyzeMappings(readyCompanyMappings, 'hubspot');
    expect(readyResult.association.status).toBe('ready');

    const warningCompanyMappings = {
      field_1: { hubspot: { object_type: 'contact', property_name: 'email' } },
      field_2: { hubspot: { object_type: 'company', property_name: 'city' } }
    };
    const warningResult = analyzeMappings(warningCompanyMappings, 'hubspot');
    expect(warningResult.association.status).toBe('warning');
  });
});

