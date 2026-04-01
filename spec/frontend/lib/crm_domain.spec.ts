import { describe, it, expect } from 'vitest';
import { mapCrmPrefillToForm, isCompanyInfoCompleted } from '@/lib/crm_domain';

describe('mapCrmPrefillToForm', () => {
  it('returns empty object for null/undefined input', () => {
    expect(mapCrmPrefillToForm(null)).toEqual({});
    expect(mapCrmPrefillToForm(undefined)).toEqual({});
  });

  it('maps all CRM contact fields to form fields', () => {
    const crmData = {
      name: 'John Doe',
      email: 'john@example.com',
      phone: '+1-555-0001',
      company_name: 'Acme Corp',
      company_id: 'REG-42',
      country: 'FR',
      address: { street: '123 Main St', city: 'Paris', postal_code: '75001' }
    };

    const result = mapCrmPrefillToForm(crmData);

    expect(result).toEqual({
      name: 'John Doe',
      email: 'john@example.com',
      phone: '+1-555-0001',
      companyName: 'Acme Corp',
      companyId: 'REG-42',
      selectedCountry: 'FR',
      street: '123 Main St',
      city: 'Paris',
      postal: '75001'
    });
  });

  it('maps merged contact+company response (company overrides)', () => {
    // Simulates what the backend returns when company data is merged
    const mergedCrmData = {
      name: 'Jane Smith',
      email: 'jane@example.com',
      phone: '+33-1-2345',       // from company
      company_name: 'Corp SA',   // from company
      company_id: 'SIREN-123',   // from company (registration_number)
      country: 'FR',             // from company
      domain: 'corp.fr',         // from company (not mapped to form)
      address: { street: '10 Rue du Commerce', city: 'Lyon', postal_code: '69001' }
    };

    const result = mapCrmPrefillToForm(mergedCrmData);

    expect(result.name).toBe('Jane Smith');
    expect(result.companyName).toBe('Corp SA');
    expect(result.companyId).toBe('SIREN-123');
    expect(result.phone).toBe('+33-1-2345');
    expect(result.selectedCountry).toBe('FR');
    expect(result.street).toBe('10 Rue du Commerce');
    expect(result.city).toBe('Lyon');
    expect(result.postal).toBe('69001');
  });

  it('omits fields that are empty/falsy as undefined', () => {
    const crmData = {
      name: 'Only Name',
      email: '',
      phone: null,
      company_name: undefined,
      address: {}
    };

    const result = mapCrmPrefillToForm(crmData);

    expect(result.name).toBe('Only Name');
    expect(result.email).toBeUndefined();
    expect(result.phone).toBeUndefined();
    expect(result.companyName).toBeUndefined();
    expect(result.street).toBeUndefined();
  });
});

describe('isCompanyInfoCompleted', () => {
  it('returns false when name is null/empty', () => {
    expect(isCompanyInfoCompleted(null, 'REG-1')).toBe(false);
    expect(isCompanyInfoCompleted('', 'REG-1')).toBe(false);
  });

  it('returns false when id is null/empty', () => {
    expect(isCompanyInfoCompleted('Acme', null)).toBe(false);
    expect(isCompanyInfoCompleted('Acme', '')).toBe(false);
  });

  it('returns false when name is too short', () => {
    expect(isCompanyInfoCompleted('AB', 'REG-1')).toBe(false);
  });

  it('returns false when id is too short', () => {
    expect(isCompanyInfoCompleted('Acme Corp', 'R')).toBe(false);
  });

  it('returns true for valid company info', () => {
    expect(isCompanyInfoCompleted('Acme Corp', 'REG-123')).toBe(true);
  });
});
