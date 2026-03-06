import { describe, it, expect } from 'vitest';
import { areTypesCompatible, getFieldDataType } from './crm-utils';

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
