import { describe, it, expect } from 'vitest';
import { areTypesCompatible, getFieldDataType, analyzeMappings, autoMapFields } from './crm-utils';

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

  it('matches by field label', () => {
    const fields = [{ id: '1', label: 'First Name', field_type: 'text', metadata: {} }];
    const result = autoMapFields(fields, mockProperties);
    
    expect(result['1'].hubspot).toBeDefined();
    expect(result['1'].hubspot.property_name).toBe('firstname');
  });

  it('prioritizes export_key even when label differs', () => {
    const fields = [{ 
      id: '1', 
      label: 'Your Mobile', 
      field_type: 'text', 
      metadata: { export_key: 'phone' } as any
    }];
    const result = autoMapFields(fields, mockProperties);
    
    // Label "Your Mobile" doesn't match "Phone Number", 
    // but export_key "phone" matches CRM property name "phone"
    expect(result['1'].hubspot).toBeDefined();
    expect(result['1'].hubspot.property_name).toBe('phone');
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
    
    expect(result['1'].hubspot.property_name).toBe('firstname');
    expect(result['1'].salesforce.property_name).toBe('FirstName');
  });

  it('skips incompatible types', () => {
    const fields = [{ 
      id: '1', 
      label: 'Email', 
      field_type: 'number', // Number vs String in CRM
      metadata: {} 
    }];
    const result = autoMapFields(fields, mockProperties);
    
    // Email exists but type mismatch (number vs string)
    expect(result['1'].hubspot).toBeUndefined();
  });
});

