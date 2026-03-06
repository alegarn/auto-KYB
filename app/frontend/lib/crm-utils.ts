export type DataType = 'string' | 'number' | 'boolean' | 'date' | 'file' | 'json' | 'unknown';

export function getFieldDataType(field_type: string): DataType {
  switch (field_type) {
    case 'text':
    case 'email':
    case 'textarea':
    case 'select':
    case 'radio':
    case 'buttons':
      return 'string';
    case 'number':
      return 'number';
    case 'checkbox':
      return 'boolean';
    case 'date':
      return 'date';
    case 'file':
      return 'file';
    case 'table':
      return 'json';
    default:
      return 'unknown';
  }
}

export function areTypesCompatible(formFieldType: string, crmPropertyType: string): boolean {
  if (!formFieldType || !crmPropertyType) return true;

  const dataType = getFieldDataType(formFieldType);
  const propType = crmPropertyType.toLowerCase();

  // Basic compatibility mapping
  // This can be expanded as we learn more about CRM specific types (HubSpot, Salesforce, etc.)
  
  const compatibilityMap: Record<DataType, string[]> = {
    'string': ['string', 'text', 'textarea', 'email', 'phone', 'url', 'select', 'radio', 'enumeration'],
    'number': ['number', 'integer', 'float', 'decimal', 'price'],
    'boolean': ['boolean', 'bool', 'checkbox', 'yesno', 'enumeration'],
    'date': ['date', 'datetime'],
    'file': ['file', 'string', 'text', 'url'],
    'json': ['string', 'text', 'textarea', 'json'],
    'unknown': ['string', 'text']
  };

  // If we have a defined set of compatible types for the dataType
  if (compatibilityMap[dataType]) {
    return compatibilityMap[dataType].includes(propType);
  }

  // Fallback: most things can be stored in a string/text field in CRM
  if (['string', 'text', 'textarea'].includes(propType)) return true;

  return false;
}
