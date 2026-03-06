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

/**
 * Required identifier properties per CRM provider and object type.
 * A CRM record of a given object_type needs at least ONE of these properties
 * mapped to be successfully created.
 */
export const CRM_REQUIRED_IDENTIFIERS: Record<string, Record<string, string[]>> = {
  hubspot: {
    company: ['name', 'domain'],
    contact: ['email'],
  },
  salesforce: {
    company: ['Name'],
    contact: ['Email'],
  },
  zoho: {
    company: ['Company_Name'],
    contact: ['Email'],
  },
};

export type CrmObjectStatus = 'ready' | 'warning' | 'none';

export interface CrmExportSummary {
  contact: { status: CrmObjectStatus; count: number; message: string };
  company: { status: CrmObjectStatus; count: number; message: string; missingIdentifiers?: string[] };
  association: { status: CrmObjectStatus; message: string };
}

/**
 * Analyzes current field mappings to determine what CRM records will be created
 * for a given provider. CRM-agnostic — uses the provider key to look up required identifiers.
 */
export function analyzeMappings(
  mappings: Record<string, Record<string, any>>,
  provider: string,
): CrmExportSummary {
  let contactCount = 0;
  let companyCount = 0;
  const mappedCompanyProps: string[] = [];

  for (const fieldId of Object.keys(mappings)) {
    const providerMapping = mappings[fieldId]?.[provider];
    if (!providerMapping) continue;

    const objType = providerMapping.object_type;
    if (objType === 'contact') contactCount++;
    if (objType === 'company') {
      companyCount++;
      if (providerMapping.property_name) {
        mappedCompanyProps.push(providerMapping.property_name);
      }
    }
  }

  // Contact status
  const contact: CrmExportSummary['contact'] = contactCount > 0
    ? { status: 'ready', count: contactCount, message: `Contact will be created/updated (${contactCount} field${contactCount > 1 ? 's' : ''})` }
    : { status: 'none', count: 0, message: 'No contact fields mapped — no contact will be created' };

  // Company status
  const requiredIds = CRM_REQUIRED_IDENTIFIERS[provider]?.company || [];
  const hasMappedIdentifier = requiredIds.length === 0 || requiredIds.some(id => mappedCompanyProps.includes(id));

  let company: CrmExportSummary['company'];
  if (companyCount === 0) {
    company = { status: 'none', count: 0, message: 'No company fields mapped — no company will be created' };
  } else if (!hasMappedIdentifier) {
    const missing = requiredIds.filter(id => !mappedCompanyProps.includes(id));
    company = {
      status: 'warning',
      count: companyCount,
      message: `Company fields mapped but missing required identifier (${missing.join(' or ')})`,
      missingIdentifiers: missing,
    };
  } else {
    company = { status: 'ready', count: companyCount, message: `Company will be created/updated (${companyCount} field${companyCount > 1 ? 's' : ''})` };
  }

  // Association status
  const association: CrmExportSummary['association'] =
    contact.status === 'ready' && company.status === 'ready'
      ? { status: 'ready', message: 'Contact & Company will be linked' }
      : contact.status === 'ready' && company.status === 'warning'
        ? { status: 'warning', message: 'Association may fail — company missing required identifier' }
        : { status: 'none', message: 'No association (need both contact and company fields)' };

  return { contact, company, association };
}

export function autoMapFields(fields: any[], crmProperties: Record<string, any>): Record<string, Record<string, any>> {
  const newMappings: Record<string, Record<string, any>> = {};

  fields.forEach(field => {
    const fieldId = field.id;
    const fieldLabel = (field.label || field.id || '').toLowerCase();
    newMappings[fieldId] = {};

    Object.entries(crmProperties).forEach(([provider, properties]) => {
      // Loop through object types (contact, company)
      for (const objType of ['contact', 'company']) {
        const props = properties[objType] || [];
        
        // Find a matching property by name or label, and check type compatibility
        const match = props.find((p: any) => {
          const propName = (p.name || '').toLowerCase();
          const propLabel = (p.label || '').toLowerCase();
          
          if (propName === fieldLabel || propLabel === fieldLabel || propName === fieldId.toLowerCase()) {
            return areTypesCompatible(field.field_type, p.type);
          }
          return false;
        });

        if (match) {
          newMappings[fieldId][provider] = {
            type: 'existing',
            object_type: objType,
            property_name: match.name
          };
          break; // Stop looking in other object types once matched for this provider
        }
      }
    });
  });

  return newMappings;
}
