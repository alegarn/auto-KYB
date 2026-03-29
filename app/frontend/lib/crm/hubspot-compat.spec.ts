import { describe, it, expect } from 'vitest';
import { isHubSpotCompatible, hubSpotSubtypeBonus, type HubSpotProp } from './hubspot-compat';

// Helper fields
const singleSelect   = { field_type: 'select' };
const singleRadio    = { field_type: 'radio' };
const singleCheckbox = { field_type: 'checkbox' };                              // single_choice (no allow_multiple)
const multiCheckbox  = { field_type: 'checkbox', metadata: { allow_multiple: true } };
const textField      = { field_type: 'text' };
const numberField    = { field_type: 'number' };
const dateField      = { field_type: 'date' };

// ── US-11: booleancheckbox ────────────────────────────────────────────────────
describe('isHubSpotCompatible — booleancheckbox', () => {
  const prop: HubSpotProp = { name: 'opted_out', type: 'enumeration', field_type: 'booleancheckbox' };

  it('US-11a: accepts a single_choice checkbox field (yes/no toggle)', () => {
    expect(isHubSpotCompatible(singleCheckbox, prop)).toBe(true);
  });

  it('US-11b: accepts a select field (single_choice)', () => {
    expect(isHubSpotCompatible(singleSelect, prop)).toBe(true);
  });

  it('US-11c: accepts a radio field (single_choice)', () => {
    expect(isHubSpotCompatible(singleRadio, prop)).toBe(true);
  });

  it('US-11d: rejects a multi_choice field', () => {
    expect(isHubSpotCompatible(multiCheckbox, prop)).toBe(false);
  });

  it('US-11e: rejects a text (string) field', () => {
    expect(isHubSpotCompatible(textField, prop)).toBe(false);
  });
});

describe('isHubSpotCompatible — calculation_equation', () => {
  const prop: HubSpotProp = { name: 'score', type: 'enumeration', field_type: 'calculation_equation' };

  it('rejects all fields because calculation properties are computed/read-only', () => {
    expect(isHubSpotCompatible(singleSelect, prop)).toBe(false);
    expect(isHubSpotCompatible(singleCheckbox, prop)).toBe(false);
    expect(isHubSpotCompatible(multiCheckbox, prop)).toBe(false);
    expect(isHubSpotCompatible(numberField, prop)).toBe(false);
    expect(isHubSpotCompatible(textField, prop)).toBe(false);
  });
});

// ── US-04: checkbox (multi-select enumeration) ────────────────────────────────
describe('isHubSpotCompatible — enumeration/checkbox', () => {
  const prop: HubSpotProp = { name: 'buying_roles', type: 'enumeration', field_type: 'checkbox' };

  it('US-04a: accepts a multi_choice field', () => {
    expect(isHubSpotCompatible(multiCheckbox, prop)).toBe(true);
  });

  it('US-04b: rejects a single_choice field', () => {
    expect(isHubSpotCompatible(singleSelect, prop)).toBe(false);
    expect(isHubSpotCompatible(singleCheckbox, prop)).toBe(false);
  });

  it('US-04c: rejects a text field', () => {
    expect(isHubSpotCompatible(textField, prop)).toBe(false);
  });
});

// ── US-01 / US-02: select / radio (single-select enumeration) ─────────────────
describe('isHubSpotCompatible — enumeration/select', () => {
  const prop: HubSpotProp = { name: 'hs_lead_status', type: 'enumeration', field_type: 'select' };

  it('US-01a: accepts a select form field', () => {
    expect(isHubSpotCompatible(singleSelect, prop)).toBe(true);
  });

  it('US-01b: accepts a radio form field', () => {
    expect(isHubSpotCompatible(singleRadio, prop)).toBe(true);
  });

  it('US-01c: accepts a single-choice checkbox form field', () => {
    expect(isHubSpotCompatible(singleCheckbox, prop)).toBe(true);
  });

  it('US-01d: rejects a multi_choice field', () => {
    expect(isHubSpotCompatible(multiCheckbox, prop)).toBe(false);
  });

  it('US-01e: rejects a text (string) field — text must NOT map to select enum', () => {
    expect(isHubSpotCompatible(textField, prop)).toBe(false);
  });
});

describe('isHubSpotCompatible — enumeration/radio', () => {
  const prop: HubSpotProp = { name: 'hs_lifecyclestage', type: 'enumeration', field_type: 'radio' };

  it('accepts single_choice fields', () => {
    expect(isHubSpotCompatible(singleSelect, prop)).toBe(true);
    expect(isHubSpotCompatible(singleRadio, prop)).toBe(true);
  });

  it('rejects multi_choice fields', () => {
    expect(isHubSpotCompatible(multiCheckbox, prop)).toBe(false);
  });

  it('rejects text fields', () => {
    expect(isHubSpotCompatible(textField, prop)).toBe(false);
  });
});

// ── Non-enumeration HubSpot types fall back to generic compat ─────────────────
describe('isHubSpotCompatible — non-enumeration types', () => {
  it('accepts string field for string-type HubSpot property', () => {
    const prop: HubSpotProp = { name: 'firstname', type: 'string', field_type: 'text' };
    expect(isHubSpotCompatible(textField, prop)).toBe(true);
  });

  it('accepts number field for number-type HubSpot property', () => {
    const prop: HubSpotProp = { name: 'num_employees', type: 'number', field_type: 'number' };
    expect(isHubSpotCompatible(numberField, prop)).toBe(true);
  });

  it('rejects incompatible types (number field vs date property)', () => {
    const prop: HubSpotProp = { name: 'closedate', type: 'date', field_type: 'date' };
    expect(isHubSpotCompatible(numberField, prop)).toBe(false);
  });
});

// ── hubSpotSubtypeBonus ───────────────────────────────────────────────────────
describe('hubSpotSubtypeBonus', () => {
  it('returns 1 when multi_choice matches a checkbox enum', () => {
    const prop: HubSpotProp = { name: 'buying_roles', type: 'enumeration', field_type: 'checkbox' };
    expect(hubSpotSubtypeBonus('multi_choice', prop)).toBe(1);
  });

  it('returns 1 when single_choice matches a select enum', () => {
    const prop: HubSpotProp = { name: 'status', type: 'enumeration', field_type: 'select' };
    expect(hubSpotSubtypeBonus('single_choice', prop)).toBe(1);
  });

  it('returns 0 on single_choice vs checkbox mismatch', () => {
    const prop: HubSpotProp = { name: 'buying_roles', type: 'enumeration', field_type: 'checkbox' };
    expect(hubSpotSubtypeBonus('single_choice', prop)).toBe(0);
  });

  it('returns 0 for non-enumeration properties', () => {
    const prop: HubSpotProp = { name: 'firstname', type: 'string', field_type: 'text' };
    expect(hubSpotSubtypeBonus('single_choice', prop)).toBe(0);
  });

  it('returns 0 for enumeration without a field_type', () => {
    const prop: HubSpotProp = { name: 'status', type: 'enumeration' };
    expect(hubSpotSubtypeBonus('single_choice', prop)).toBe(0);
  });
});
