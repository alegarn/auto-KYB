/**
 * HubSpot-specific CRM compatibility helpers.
 *
 * This module is intentionally isolated from the generic crm-utils.ts so that
 * HubSpot field-type knowledge (checkbox, select, radio, booleancheckbox) is
 * never bundled into non-HubSpot flows.  Import this only when the active
 * provider is "hubspot".
 */

import { type DataType, getFieldDataType, areTypesCompatible } from '../crm-utils';

export interface HubSpotProp {
  name: string;
  type: string;
  /** HubSpot display field type: select | radio | checkbox | booleancheckbox | text | textarea | … */
  field_type?: string;
  options?: Array<{ label: string; value: string }>;
  read_only?: boolean;
}

/**
 * Returns whether a form field is compatible with a HubSpot property,
 * respecting HubSpot's enumeration sub-types.
 *
 * HubSpot enumeration sub-type rules:
 *   - booleancheckbox → single-value toggle (values "true"/"false")
 *                       compatible with: boolean, single_choice
 *   - checkbox        → multi-select (semicolon-separated values)
 *                       compatible with: multi_choice
 *   - select / radio  → single-select dropdown / radio group
 *                       compatible with: single_choice only (NOT string)
 *
 * For non-enumeration HubSpot types the generic areTypesCompatible is used.
 */
export function isHubSpotCompatible(formField: any, prop: HubSpotProp): boolean {
  const dataType = getFieldDataType(formField);
  const fieldType = prop.field_type?.toLowerCase();

  // Calculation equations are computed by HubSpot based on other properties.
  // They are implicitly read-only and cannot accept incoming form data.
  if (fieldType === 'calculation_equation') {
    return false;
  }

  // booleancheckbox: an enumeration whose only valid values are "true"/"false".
  // A boolean form field OR a single-choice field (yes/no form checkbox) maps here.
  if (fieldType === 'booleancheckbox') {
    return dataType === 'boolean' || dataType === 'single_choice';
  }

  // enumeration with a known sub-type → enforce single ↔ single, multi ↔ multi
  if (prop.type === 'enumeration' && fieldType) {
    const isMultiCrm = fieldType === 'checkbox';
    if (isMultiCrm) return dataType === 'multi_choice';
    // select / radio: single_choice only — string/text fields are NOT compatible
    return dataType === 'single_choice';
  }

  // Delegate everything else to the provider-agnostic function
  return areTypesCompatible(formField, prop.type);
}

/**
 * Returns a sort bonus (0 or 1) for auto-mapping: prefer HubSpot enumeration
 * properties whose multiplicity matches the form field's multiplicity.
 */
export function hubSpotSubtypeBonus(dataType: DataType, prop: HubSpotProp): number {
  if (prop.type !== 'enumeration' || !prop.field_type) return 0;
  const isMultiCrm = prop.field_type.toLowerCase() === 'checkbox';
  const isMultiForm = dataType === 'multi_choice';
  return isMultiCrm === isMultiForm ? 1 : 0;
}
