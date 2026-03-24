export type DataType = 'string' | 'number' | 'boolean' | 'date' | 'file' | 'json' | 'unknown';

// ── Compound Key Helpers ────────────────────────────────────────────
// A compound key encodes both CRM object type and raw property name
// into a single string: "company::address", "contact::email", etc.
// This ensures disambiguation is never lost across save/load/export.

export const CRM_KEY_SEP = '::';

/** Build a compound key: toCrmKey('company','address') → 'company::address' */
export function toCrmKey(objectType: string, propertyName: string): string {
  if (!objectType || !propertyName) return propertyName || '';
  return `${objectType}${CRM_KEY_SEP}${propertyName}`;
}

/** Parse a compound key: fromCrmKey('company::address') → { objectType:'company', propertyName:'address' } */
export function fromCrmKey(crmKey: string | undefined | null): { objectType: string; propertyName: string } {
  if (!crmKey) return { objectType: 'contact', propertyName: '' };
  const idx = crmKey.indexOf(CRM_KEY_SEP);
  if (idx === -1) return { objectType: 'contact', propertyName: crmKey };
  return { objectType: crmKey.slice(0, idx), propertyName: crmKey.slice(idx + CRM_KEY_SEP.length) };
}

/** Is this already a compound key? */
export function isCompoundKey(key: string | undefined | null): boolean {
  return !!key && key.includes(CRM_KEY_SEP);
}

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
        mappedCompanyProps.push(fromCrmKey(providerMapping.property_name).propertyName);
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

// Normalize strings for matching: lowercase, strip diacritics and non-alphanumerics
function normalizeForMatch(s?: string | null): string {
  if (!s) return '';
  const str = String(s).toLowerCase().trim();
  const withoutDiacritics = (str.normalize && str.normalize('NFD')) ? str.normalize('NFD').replace(/[\u0300-\u036f]/g, '') : str;
  return withoutDiacritics.replace(/[^a-z0-9]+/g, '');
}

// Classic Levenshtein distance implementation
function levenshteinDistance(a: string, b: string): number {
  if (a === b) return 0;
  const alen = a.length;
  const blen = b.length;
  if (alen === 0) return blen;
  if (blen === 0) return alen;

  const v0 = new Array(alen + 1);
  const v1 = new Array(alen + 1);

  for (let i = 0; i <= alen; i++) v0[i] = i;

  for (let i = 0; i < blen; i++) {
    v1[0] = i + 1;
    for (let j = 0; j < alen; j++) {
      const cost = a[j] === b[i] ? 0 : 1;
      v1[j + 1] = Math.min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
    }
    for (let j = 0; j <= alen; j++) v0[j] = v1[j];
  }
  return v1[alen];
}

function similarityScore(a: string, b: string): number {
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 1;
  const dist = levenshteinDistance(a, b);
  return 1 - dist / maxLen;
}

export function autoMapFields(fields: any[], crmProperties: Record<string, any>): Record<string, Record<string, any>> {
  const newMappings: Record<string, Record<string, any>> = {};

  fields.forEach(field => {
    const rawFieldId = field?.id;
    // Skip fields without a stable string id (e.g., section dividers)
    if (!rawFieldId || typeof rawFieldId !== 'string') return;

    const fieldId = rawFieldId;
    const fieldLabel = String(field.label || fieldId || '').toLowerCase();
    const fieldLabelNorm = normalizeForMatch(field.label || fieldId || '');
    const fieldIdNorm = normalizeForMatch(fieldId);
    
    // Use export_key as a matching feature if available
    const exportKey = (field.metadata?.export_key || '').toLowerCase();
    const exportKeyNorm = exportKey ? normalizeForMatch(exportKey) : '';

    newMappings[fieldId] = {};

    Object.entries(crmProperties).forEach(([provider, properties]) => {
      // Loop through object types (contact, company)
      for (const objType of ['contact', 'company']) {
        const props = properties[objType] || [];

        // 1) Try exact match first (avoid false positives)
        const exactMatch = props.find((p: any) => {
          const propName = String(p.name || '').toLowerCase();
          const propLabel = String(p.label || '').toLowerCase();
          const propNameNorm = normalizeForMatch(p.name);
          const propLabelNorm = normalizeForMatch(p.label);
          const fieldIdLower = String(fieldId).toLowerCase();

          // Try match against label, ID or EXPORT KEY
          const matchesRaw = propName === fieldLabel || propLabel === fieldLabel || propName === fieldIdLower || propName === exportKey || propLabel === exportKey;

          if (matchesRaw) {
            return areTypesCompatible(field.field_type, p.type);
          }
          // Also allow exact match on normalized strings (handles punctuation/diacritics)
          const matchesNorm = (propNameNorm && (propNameNorm === fieldLabelNorm || propNameNorm === exportKeyNorm)) || 
                             (propLabelNorm && (propLabelNorm === fieldLabelNorm || propLabelNorm === exportKeyNorm));

          if (matchesNorm) {
            return areTypesCompatible(field.field_type, p.type);
          }
          return false;
        });

        if (exactMatch) {
          newMappings[fieldId][provider] = {
            type: 'existing',
            object_type: objType,
            property_name: toCrmKey(objType, exactMatch.name)
          };
          break; // Stop looking in other object types once matched for this provider
        }

        // 2) Fuzzy matching: find best candidate by Levenshtein distance / similarity
        let best: { prop: any; distance: number; similarity: number } | null = null;
        for (const p of props) {
          if (!areTypesCompatible(field.field_type, p.type)) continue;
          const propNameNorm = normalizeForMatch(p.name);
          const propLabelNorm = normalizeForMatch(p.label);
          if (!propNameNorm && !propLabelNorm) continue;

          // Evaluate against both name and label
          let candidateDistance = Infinity;
          let candidateSimilarity = -1;
          if (propNameNorm) {
            const d = levenshteinDistance(fieldLabelNorm, propNameNorm);
            const s = similarityScore(fieldLabelNorm, propNameNorm);
            if (d < candidateDistance || (d === candidateDistance && s > candidateSimilarity)) {
              candidateDistance = d;
              candidateSimilarity = s;
            }
          }
          if (propLabelNorm) {
            const d = levenshteinDistance(fieldLabelNorm, propLabelNorm);
            const s = similarityScore(fieldLabelNorm, propLabelNorm);
            if (d < candidateDistance || (d === candidateDistance && s > candidateSimilarity)) {
              candidateDistance = d;
              candidateSimilarity = s;
            }
          }

          if (!best || candidateDistance < best.distance || (candidateDistance === best.distance && candidateSimilarity > best.similarity)) {
            best = { prop: p, distance: candidateDistance, similarity: candidateSimilarity };
          }
        }

        // Accept fuzzy match if it's reasonably close
        if (best && (best.distance <= 2 || best.similarity >= 0.8)) {
          newMappings[fieldId][provider] = {
            type: 'existing',
            object_type: objType,
            property_name: toCrmKey(objType, best.prop.name)
          };
          break;
        }
      }
    });
  });

  return newMappings;
}

export type FileMappingAction = {
  value: string;
  label: string;
};

export function getProviderFileActions(provider: string): FileMappingAction[] {
  switch (provider.toLowerCase()) {
    case 'hubspot':
      return [
        { value: 'contact:__note_attachment__', label: 'Attach as Note to Contact' },
        { value: 'company:__note_attachment__', label: 'Attach as Note to Company' }
      ];
    case 'salesforce':
      return [
        { value: 'contact:__content_version__', label: 'Attach as ContentVersion to Contact' },
        { value: 'company:__content_version__', label: 'Attach as ContentVersion to Account' }
      ];
    case 'zoho':
      return [
        { value: 'contact:__attachment__', label: 'Attach to Contact' },
        { value: 'company:__attachment__', label: 'Attach to Account' }
      ];
    default:
      return [];
  }
}
