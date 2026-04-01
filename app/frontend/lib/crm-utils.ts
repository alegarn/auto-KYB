export type DataType = 'string' | 'number' | 'boolean' | 'date' | 'file' | 'json' | 'single_choice' | 'multi_choice' | 'unknown';

// ── Compound Key Helpers ────────────────────────────────────────────
// A compound key encodes both CRM object type and raw property name
// into a single string: "company::address", "contact::email", etc.
// This ensures disambiguation is never lost across save/load/export.

export const CRM_KEY_SEP = '::';

const CRM_OBJECT_LABELS: Record<string, Record<string, string>> = {
  hubspot: {
    contact: 'Contact',
    company: 'Company',
  },
  salesforce: {
    contact: 'Contact',
    company: 'Account',
  },
  zoho: {
    contact: 'Contact',
    company: 'Account',
  },
};

export function getCrmObjectLabel(provider: string, objectType: string): string {
  const providerKey = String(provider || '').toLowerCase();
  const objectKey = String(objectType || '').toLowerCase();

  return CRM_OBJECT_LABELS[providerKey]?.[objectKey]
    || (objectKey ? objectKey.charAt(0).toUpperCase() + objectKey.slice(1) : 'Record');
}

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

export type FieldLike = { field_type: string; metadata?: { allow_multiple?: boolean } };

export function getFieldDataType(field: string | FieldLike): DataType {
  const f = typeof field === 'string' ? { field_type: field } : field;
  const { field_type, metadata } = f;

  switch (field_type) {
    case 'select':
    case 'radio':
      return 'single_choice';
    case 'checkbox':
    case 'buttons':
      return metadata?.allow_multiple === true ? 'multi_choice' : 'single_choice';
    case 'number':
      return 'number';
    case 'date':
      return 'date';
    case 'file':
      return 'file';
    case 'table':
      return 'json';
    case 'text':
    case 'email':
    case 'textarea':
      return 'string';
    default:
      return 'unknown';
  }
}

export function areTypesCompatible(formField: any, crmPropertyType: string, _crmFieldType?: string): boolean {
  if (!formField || !crmPropertyType) return true;

  const dataType = getFieldDataType(formField);
  const propType = crmPropertyType.toLowerCase();

  // Generic compatibility mapping — provider-agnostic.
  // For provider-specific sub-type discrimination (e.g. HubSpot enumeration/checkbox vs select),
  // use the provider's own compat module (e.g. isHubSpotCompatible from crm/hubspot-compat).
  const compatibilityMap: Record<DataType, string[]> = {
    'single_choice': ['enumeration', 'string', 'text', 'textarea', 'email', 'phone', 'url', 'select', 'radio'],
    'multi_choice':  ['enumeration', 'string', 'text', 'checkbox'],
    'string':        ['string', 'text', 'textarea', 'email', 'phone', 'url', 'select', 'radio'],
    'number':        ['number', 'integer', 'float', 'decimal', 'price'],
    'boolean':       ['boolean', 'bool', 'checkbox', 'yesno', 'enumeration'],
    'date':          ['date', 'datetime'],
    'file':          ['file', 'string', 'text', 'url'],
    'json':          ['string', 'text', 'textarea', 'json'],
    'unknown':       ['string', 'text']
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

const CRM_OBJECT_HINTS: Record<string, string[]> = {
  contact: ['contact', 'person', 'individual', 'lead'],
  company: ['company', 'business', 'organization', 'organisation', 'org', 'account', 'firm', 'corporation', 'corp', 'enterprise'],
};

const CRM_OBJECT_PREFERRED_TERMS: Record<string, string[]> = {
  contact: ['first', 'last', 'full'],
  company: ['address', 'street', 'city', 'state', 'postal', 'zip', 'country', 'domain', 'website', 'industry', 'vat', 'tax', 'registration', 'revenue'],
};

function normalizeForWords(s?: string | null): string {
  if (!s) return '';
  const str = String(s).toLowerCase().trim();
  const withoutDiacritics = (str.normalize && str.normalize('NFD')) ? str.normalize('NFD').replace(/[\u0300-\u036f]/g, '') : str;
  return withoutDiacritics.replace(/[^a-z0-9]+/g, ' ').trim();
}

function uniqueNonEmpty(values: Array<string | undefined | null>): string[] {
  return [...new Set(values.map(value => value?.trim()).filter((value): value is string => !!value))];
}

function getObjectAwareVariants(value: string | undefined | null, objectType: string): string[] {
  const wordForm = normalizeForWords(value);
  if (!wordForm) return [];

  const hints = CRM_OBJECT_HINTS[objectType] || [];
  const words = wordForm.split(/\s+/).filter(Boolean);
  const strippedWords = words.filter(word => !hints.includes(word));

  return uniqueNonEmpty([
    normalizeForMatch(wordForm),
    strippedWords.length > 0 ? normalizeForMatch(strippedWords.join(' ')) : '',
  ]);
}

function getObjectPreferenceScore(values: Array<string | undefined | null>, objectType: string): number {
  const wordHints = CRM_OBJECT_HINTS[objectType] || [];
  const preferredTerms = CRM_OBJECT_PREFERRED_TERMS[objectType] || [];

  return values.reduce((score, value) => {
    const words = normalizeForWords(value).split(/\s+/).filter(Boolean);
    if (words.length === 0) return score;

    let nextScore = score;
    if (words.some(word => wordHints.includes(word))) nextScore += 3;
    if (words.some(word => preferredTerms.includes(word))) nextScore += 1;
    return nextScore;
  }, 0);
}

type MatchTier = 'raw-exact' | 'normalized-exact' | 'object-aware-exact' | 'fuzzy';

type MatchCandidate = {
  prop: any;
  object_type: string;
  tier: MatchTier;
  distance: number;
  similarity: number;
  objectPreference: number;
  subtypeBonus: number;
};

function compareCandidates(left: MatchCandidate, right: MatchCandidate): number {
  const tierOrder: Record<MatchTier, number> = {
    'raw-exact': 4,
    'normalized-exact': 3,
    'object-aware-exact': 2,
    'fuzzy': 1,
  };

  const tierDelta = tierOrder[left.tier] - tierOrder[right.tier];
  if (tierDelta !== 0) return tierDelta;

  const subtypeDelta = (left.subtypeBonus || 0) - (right.subtypeBonus || 0);
  if (subtypeDelta !== 0) return subtypeDelta;

  const preferenceDelta = left.objectPreference - right.objectPreference;
  if (preferenceDelta !== 0) return preferenceDelta;

  const similarityDelta = left.similarity - right.similarity;
  if (similarityDelta !== 0) return similarityDelta;

  return right.distance - left.distance;
}

function shouldAcceptCandidate(candidate: MatchCandidate | null): boolean {
  if (!candidate) return false;
  if (candidate.tier !== 'fuzzy') return true;

  return candidate.distance <= 2 || candidate.similarity >= 0.85 || (candidate.objectPreference > 0 && candidate.similarity >= 0.75);
}

export function autoMapFields(
  fields: any[],
  crmProperties: Record<string, any>,
  providerIsCompatible?: (field: any, prop: any, provider: string) => boolean
): Record<string, Record<string, any>> {
  const newMappings: Record<string, Record<string, any>> = {};

  fields.forEach((field, index) => {
    const rawFieldId = field?.id;
    const fieldId = (rawFieldId && typeof rawFieldId === 'string') ? rawFieldId : `draft:${index}`;

    const fieldLabel = String(field.label || fieldId || '').toLowerCase();
    const fieldLabelNorm = normalizeForMatch(field.label || fieldId || '');
    const fieldIdNorm = normalizeForMatch(fieldId);
    
    // Use export_key as a matching feature if available
    const exportKey = (field.metadata?.export_key || '').toLowerCase();
    const exportKeyNorm = exportKey ? normalizeForMatch(exportKey) : '';
    const rawFieldTerms = uniqueNonEmpty([fieldLabel, String(fieldId).toLowerCase(), exportKey]);
    const normalizedFieldTerms = uniqueNonEmpty([fieldLabelNorm, fieldIdNorm, exportKeyNorm]);

    newMappings[fieldId] = {};

    Object.entries(crmProperties).forEach(([provider, properties]) => {
      let bestCandidate: MatchCandidate | null = null;

      for (const objType of ['contact', 'company']) {
        const props = properties[objType] || [];
        const objectAwareTerms = uniqueNonEmpty([
          ...rawFieldTerms.flatMap(term => getObjectAwareVariants(term, objType)),
          ...normalizedFieldTerms,
        ]);
        const objectPreference = getObjectPreferenceScore([field.label, fieldId, exportKey], objType);
        const formDataType = getFieldDataType(field);

        for (const p of props) {
          const compatible = providerIsCompatible
            ? providerIsCompatible(field, p, provider)
            : areTypesCompatible(field, p.type);
          if (!compatible) continue;

          let subtypeBonus = 0;
          if (p.type === 'enumeration' && p.field_type) {
            const isMultiCrm = p.field_type.toLowerCase() === 'checkbox';
            const isMultiForm = formDataType === 'multi_choice';
            if (isMultiCrm === isMultiForm) subtypeBonus = 1;
          }

          const propName = String(p.name || '').toLowerCase();
          const propLabel = String(p.label || '').toLowerCase();
          const propNameNorm = normalizeForMatch(p.name);
          const propLabelNorm = normalizeForMatch(p.label);

          const matchesRaw = rawFieldTerms.some(term => term === propName || term === propLabel);
          if (matchesRaw) {
            const candidate: MatchCandidate = {
              prop: p,
              object_type: objType,
              tier: 'raw-exact',
              distance: 0,
              similarity: 1,
              objectPreference,
              subtypeBonus,
            };
            if (!bestCandidate || compareCandidates(candidate, bestCandidate) > 0) bestCandidate = candidate;
            continue;
          }

          const matchesNorm = normalizedFieldTerms.some(term => term === propNameNorm || term === propLabelNorm);
          if (matchesNorm) {
            const candidate: MatchCandidate = {
              prop: p,
              object_type: objType,
              tier: 'normalized-exact',
              distance: 0,
              similarity: 1,
              objectPreference,
              subtypeBonus,
            };
            if (!bestCandidate || compareCandidates(candidate, bestCandidate) > 0) bestCandidate = candidate;
            continue;
          }

          if (!propNameNorm && !propLabelNorm) continue;

          const matchesObjectAware = objectAwareTerms.some(term => term === propNameNorm || term === propLabelNorm);
          if (matchesObjectAware) {
            const candidate: MatchCandidate = {
              prop: p,
              object_type: objType,
              tier: 'object-aware-exact',
              distance: 0,
              similarity: 1,
              objectPreference,
              subtypeBonus,
            };
            if (!bestCandidate || compareCandidates(candidate, bestCandidate) > 0) bestCandidate = candidate;
            continue;
          }

          let candidateDistance = Infinity;
          let candidateSimilarity = -1;
          for (const term of objectAwareTerms) {
            if (!term) continue;

            if (propNameNorm) {
              const distance = levenshteinDistance(term, propNameNorm);
              const similarity = similarityScore(term, propNameNorm);
              if (distance < candidateDistance || (distance === candidateDistance && similarity > candidateSimilarity)) {
                candidateDistance = distance;
                candidateSimilarity = similarity;
              }
            }

            if (propLabelNorm) {
              const distance = levenshteinDistance(term, propLabelNorm);
              const similarity = similarityScore(term, propLabelNorm);
              if (distance < candidateDistance || (distance === candidateDistance && similarity > candidateSimilarity)) {
                candidateDistance = distance;
                candidateSimilarity = similarity;
              }
            }
          }

          if (!Number.isFinite(candidateDistance)) continue;

          const candidate: MatchCandidate = {
            prop: p,
            object_type: objType,
            tier: 'fuzzy',
            distance: candidateDistance,
            similarity: candidateSimilarity,
            objectPreference,
            subtypeBonus,
          };
          if (!bestCandidate || compareCandidates(candidate, bestCandidate) > 0) bestCandidate = candidate;
          }
        }

      if (bestCandidate && shouldAcceptCandidate(bestCandidate)) {
        newMappings[fieldId][provider] = {
          type: 'existing',
          object_type: bestCandidate.object_type,
          property_name: toCrmKey(bestCandidate.object_type, bestCandidate.prop.name)
        };
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
