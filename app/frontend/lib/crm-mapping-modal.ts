import type { AiSuggestion } from './crm/ai-auto-map';
import { isHubSpotCompatible } from './crm/hubspot-compat';

import { areTypesCompatible, fromCrmKey, getFieldIdentityKey, toCrmKey } from './crm-utils';

const LAYOUT_FIELD_TYPES = new Set(['section', 'subtitle', 'static_text', 'separator', 'logo']);

export type CrmMappingValue = {
  type: 'custom' | 'existing';
  object_type: string;
  property_name: string;
  read_only?: boolean;
};

export type CrmMappings = Record<string, Record<string, CrmMappingValue>>;
export type CrmExportKeyOverrides = Record<string, string>;
export type CrmOptionsOverrides = Record<string, string[]>;

export interface CrmMappingField {
  id?: string | number | null;
  label?: string | null;
  field_type: string;
  required?: boolean;
  position?: number;
  metadata?: Record<string, any>;
}

export interface CrmMappingIndexedField {
  field: CrmMappingField;
  index: number;
}

export interface CrmInventoryProperty {
  name?: string | null;
  label?: string | null;
  type?: string | null;
  field_type?: string | null;
  read_only?: boolean;
  options?: Array<{ label?: string | null; value?: string | null }>;
}

export type CrmProviderProperties = Record<string, CrmInventoryProperty[]>;

export interface CrmAiAutoMapField {
  id: string;
  label: string;
  field_type: string;
  required?: boolean;
  position?: number;
  metadata?: {
    export_key?: string;
    allow_multiple?: boolean;
    options?: string[];
  };
}

export interface CrmAiAutoMapRequest {
  unmappedFields: CrmAiAutoMapField[];
  alreadyMapped: string[];
  pendingFieldKeys: string[];
  draftFields: CrmAiAutoMapField[];
}

export interface CrmMappingDraftState {
  mappings: CrmMappings;
  exportKeyOverrides: CrmExportKeyOverrides;
  optionsOverrides: CrmOptionsOverrides;
}

interface DuplicateExportKeyEntry {
  field: CrmMappingField;
  index: number;
  baseKey: string;
  scope: string;
}

export function countAvailableWritableCrmProperties(
  providerProperties: CrmProviderProperties = {},
  mappings: CrmMappings,
  provider: string,
): number {
  const mappedPropertyKeys = new Set(
    Object.values(mappings)
      .map((providerMap) => providerMap?.[provider])
      .flatMap((mapping) => {
        const propertyName = getCrmMappingPropertyName(mapping);
        if (!mapping?.object_type || !propertyName) return [];

        return [ toCrmKey(mapping.object_type, propertyName) ];
      }),
  );

  return Object.entries(providerProperties).reduce((count, [objectType, properties]) => {
    return count + properties.filter((property) => {
      const propertyName = property?.name?.toString().trim();
      if (!propertyName || property?.read_only) return false;

      return !mappedPropertyKeys.has(toCrmKey(objectType, propertyName));
    }).length;
  }, 0);
}

export function isCrmPropertyCompatible(
  field: CrmMappingField,
  prop: CrmInventoryProperty,
  provider: string,
): boolean {
  if (provider === 'hubspot') return isHubSpotCompatible(field, prop as any);
  return areTypesCompatible(field, String(prop.type || ''));
}

export function filterCrmProperties(
  providerProperties: CrmInventoryProperty[] = [],
  search: string,
  field?: CrmMappingField,
  provider = '',
): CrmInventoryProperty[] {
  const normalizedSearch = String(search || '').trim().toLowerCase();
  const filtered = normalizedSearch
    ? providerProperties.filter((property) => {
        return (property.label || '').toLowerCase().includes(normalizedSearch)
          || (property.name || '').toLowerCase().includes(normalizedSearch);
      })
    : providerProperties;

  if (!field) return filtered;

  return filtered.slice().sort((left, right) => {
    const leftCompatible = isCrmPropertyCompatible(field, left, provider) ? 1 : 0;
    const rightCompatible = isCrmPropertyCompatible(field, right, provider) ? 1 : 0;

    if (leftCompatible !== rightCompatible) return rightCompatible - leftCompatible;

    return (left.label || left.name || '').localeCompare(right.label || right.name || '');
  });
}

export function hasCrmOptionsMismatch(
  formOptions: string[] = [],
  crmOptions: Array<{ label?: string | null; value?: string | null }> = [],
): boolean {
  if (formOptions.length === 0 || crmOptions.length === 0) return false;

  return formOptions.some((option) => {
    const normalized = String(option).trim().toLowerCase();

    return !crmOptions.some((crmOption) => {
      return (crmOption.label || '').toLowerCase() === normalized
        || (crmOption.value || '').toLowerCase() === normalized;
    });
  });
}

export function buildCrmUnmappedCounts(
  providers: string[],
  fields: CrmMappingIndexedField[],
  mappings: CrmMappings,
): Record<string, number> {
  return Object.fromEntries(
    providers.map((provider) => {
      const count = fields.reduce((total, { field, index }) => {
        const fieldKey = getCrmMappingFieldStateKey(field, index);
        return total + (mappings[fieldKey]?.[provider] ? 0 : 1);
      }, 0);

      return [provider, count];
    }),
  );
}

export function buildAiLoadingFieldKeySets(
  aiPendingFieldKeys: Record<string, string[]>,
): Record<string, Set<string>> {
  return Object.fromEntries(
    Object.entries(aiPendingFieldKeys).map(([provider, fieldKeys]) => [provider, new Set(fieldKeys)]),
  );
}

export function getCrmMappingFieldStateKey(field: CrmMappingField, index: number): string {
  return field.id !== undefined && field.id !== null ? `id:${field.id}` : `draft:${index}`;
}

export function getCrmMappingPropertyName(mapping?: CrmMappingValue | null): string {
  if (!mapping?.property_name) return '';
  return fromCrmKey(mapping.property_name).propertyName;
}

export function getCrmMappingSelectionValue(mapping?: CrmMappingValue | null): string {
  if (!mapping) return '';
  if (mapping.type === 'custom') {
    return `__custom_${mapping.object_type}__`;
  }

  const propertyName = getCrmMappingPropertyName(mapping);
  return propertyName ? `${mapping.object_type}:${propertyName}` : '';
}

export function hydrateCrmMappingDraft(fields: CrmMappingIndexedField[]): CrmMappings {
  const mappings: CrmMappings = {};

  fields.forEach(({ field, index }) => {
    const providerMap: Record<string, any> = {};
    if (field.metadata?.crm_mapping) {
      for (const [provider, rawMapping] of Object.entries(field.metadata.crm_mapping as Record<string, any>)) {
        const mapping = { ...rawMapping };
        if (mapping.property_name && mapping.object_type && !String(mapping.property_name).includes('::')) {
          mapping.property_name = toCrmKey(mapping.object_type, mapping.property_name);
        }
        providerMap[provider] = mapping;
      }
    }
    mappings[getCrmMappingFieldStateKey(field, index)] = providerMap;
  });

  return mappings;
}

export function buildCrmMappingFieldLookup(fields: CrmMappingIndexedField[]): Record<string, string> {
  return fields.reduce<Record<string, string>>((lookup, { field, index }) => {
    lookup[getFieldIdentityKey(field, index)] = getCrmMappingFieldStateKey(field, index);
    return lookup;
  }, {});
}

export function buildAiAutoMapRequest(
  fields: CrmMappingIndexedField[],
  mappings: CrmMappings,
  provider: string,
  fieldIdToStateKey: Record<string, string>,
): CrmAiAutoMapRequest {
  const draftFields = fields.map(({ field, index }) => buildAiAutoMapField(field, index));
  const unmappedFields = fields
    .filter(({ field }) => !isLayoutFieldType(field.field_type))
    .filter(({ field, index }) => !mappings[getCrmMappingFieldStateKey(field, index)]?.[provider])
    .map(({ field, index }) => buildAiAutoMapField(field, index));

  const alreadyMapped = Object.values(mappings)
    .map((providerMap) => providerMap?.[provider])
    .filter((mapping): mapping is CrmMappingValue => mapping?.type === 'existing' && !!mapping.property_name)
    .map((mapping) => mapping.property_name)
    .filter((propertyName): propertyName is string => propertyName.length > 0);

  return {
    unmappedFields,
    alreadyMapped,
    pendingFieldKeys: unmappedFields.map(({ id }) => fieldIdToStateKey[String(id)] || String(id)),
    draftFields,
  };
}

export function applyCrmMappingSelection(
  mappings: CrmMappings,
  fieldKey: string,
  provider: string,
  value: string,
  providerProperties: Record<string, Array<{ name?: string; read_only?: boolean }>> = {},
  field?: CrmMappingField,
  index = 0,
): CrmMappings {
  const nextMappings: CrmMappings = Object.fromEntries(
    Object.entries(mappings).map(([existingFieldKey, providerMap]) => [existingFieldKey, { ...providerMap }]),
  );

  if (!nextMappings[fieldKey]) {
    nextMappings[fieldKey] = {};
  }

  if (value === '__custom_contact__') {
    const propertyName = nextCustomPropertyName(
      nextMappings,
      provider,
      'contact',
      defaultCustomPropertyName(field, index),
    );
    nextMappings[fieldKey][provider] = {
      type: 'custom',
      object_type: 'contact',
      property_name: toCrmKey('contact', propertyName),
    };
  } else if (value === '__custom_company__') {
    const propertyName = nextCustomPropertyName(
      nextMappings,
      provider,
      'company',
      defaultCustomPropertyName(field, index),
    );
    nextMappings[fieldKey][provider] = {
      type: 'custom',
      object_type: 'company',
      property_name: toCrmKey('company', propertyName),
    };
  } else if (value === '') {
    delete nextMappings[fieldKey][provider];
  } else {
    const [object_type, ...rest] = value.split(':');
    const rawPropertyName = rest.join(':');

    nextMappings[fieldKey][provider] = {
      type: 'existing',
      object_type,
      property_name: toCrmKey(object_type, rawPropertyName),
      read_only: providerProperties?.[object_type]?.find((p: any) => p.name === rawPropertyName)?.read_only || false,
    };
  }

  return nextMappings;
}

export function applyCrmExportKeyAlignment(
  exportKeyOverrides: CrmExportKeyOverrides,
  fieldKey: string,
  mapping?: CrmMappingValue,
): CrmExportKeyOverrides {
  if (!mapping?.property_name) return exportKeyOverrides;

  return {
    ...exportKeyOverrides,
    [fieldKey]: getCrmMappingPropertyName(mapping),
  };
}

export function applyCrmOptionsSync(
  optionsOverrides: CrmOptionsOverrides,
  fieldKey: string,
  crmOptions: Array<{ label: string; value: string }>,
): CrmOptionsOverrides {
  return {
    ...optionsOverrides,
    [fieldKey]: crmOptions.map((option) => option.label),
  };
}

export function mergeCrmAutoMappedDraft(
  mappings: CrmMappings,
  exportKeyOverrides: CrmExportKeyOverrides,
  autoMapped: Record<string, Record<string, any>>,
  fieldIdToStateKey: Record<string, string>,
): CrmMappingDraftState {
  const nextMappings: CrmMappings = Object.fromEntries(
    Object.entries(mappings).map(([fieldKey, providerMap]) => [fieldKey, { ...providerMap }]),
  );
  const nextExportKeyOverrides: CrmExportKeyOverrides = { ...exportKeyOverrides };

  for (const [rawFieldId, providerMap] of Object.entries(autoMapped)) {
    const stateKey = fieldIdToStateKey[rawFieldId] || rawFieldId;
    if (!nextMappings[stateKey]) nextMappings[stateKey] = {};

    for (const [provider, mapping] of Object.entries(providerMap)) {
      if (!nextMappings[stateKey][provider]) {
        nextMappings[stateKey][provider] = mapping;
        if (!nextExportKeyOverrides[stateKey] && (mapping as any)?.property_name) {
          nextExportKeyOverrides[stateKey] = getCrmMappingPropertyName(mapping as CrmMappingValue);
        }
      }
    }
  }

  return {
    mappings: nextMappings,
    exportKeyOverrides: nextExportKeyOverrides,
    optionsOverrides: {},
  };
}

export function mergeAiSuggestionsDraft(
  mappings: CrmMappings,
  exportKeyOverrides: CrmExportKeyOverrides,
  suggestions: Record<string, AiSuggestion>,
  provider: string,
  fieldIdToStateKey: Record<string, string>,
): CrmMappingDraftState {
  const nextMappings: CrmMappings = Object.fromEntries(
    Object.entries(mappings).map(([fieldKey, providerMap]) => [fieldKey, { ...providerMap }]),
  );
  const nextExportKeyOverrides: CrmExportKeyOverrides = { ...exportKeyOverrides };

  for (const [rawFieldId, suggestion] of Object.entries(suggestions)) {
    const stateKey = fieldIdToStateKey[rawFieldId] || rawFieldId;

    if (!nextMappings[stateKey]) {
      nextMappings[stateKey] = {};
    }

    if (nextMappings[stateKey][provider]) continue;

    if (suggestion.suggest_custom && !suggestion.property_name && suggestion.suggested_custom_name) {
      const propertyName = nextCustomPropertyName(nextMappings, provider, suggestion.object_type, suggestion.suggested_custom_name);
      nextMappings[stateKey][provider] = {
        type: 'custom',
        object_type: suggestion.object_type,
        property_name: toCrmKey(suggestion.object_type, propertyName),
      };
      nextExportKeyOverrides[stateKey] = propertyName;
      continue;
    }

    if (!suggestion.property_name) continue;

    nextMappings[stateKey][provider] = {
      type: 'existing',
      object_type: suggestion.object_type,
      property_name: toCrmKey(suggestion.object_type, suggestion.property_name),
    };
    nextExportKeyOverrides[stateKey] = suggestion.property_name;
  }

  return {
    mappings: nextMappings,
    exportKeyOverrides: nextExportKeyOverrides,
    optionsOverrides: {},
  };
}

export function normalizeAiSuggestions(
  suggestions: Record<string, AiSuggestion>,
  fieldIdToStateKey: Record<string, string>,
): Record<string, AiSuggestion> {
  return Object.fromEntries(
    Object.entries(suggestions).map(([rawFieldId, suggestion]) => [fieldIdToStateKey[rawFieldId] || rawFieldId, suggestion]),
  );
}

export function getAiAutoMapErrorMessage(error: string): string {
  switch (error) {
    case 'ai_unavailable':
      return 'AI auto-map is temporarily unavailable. You can still use Auto-Map Fields or map fields manually.';
    case 'plan_insufficient':
      return 'Your current plan does not include AI auto-map.';
    case 'subscription_inactive':
      return 'An active subscription is required to use AI auto-map.';
    default:
      return 'AI auto-map failed. Please try again.';
  }
}

export function aiSuggestionMatchesCrmMapping(
  mapping?: CrmMappingValue | null,
  suggestion?: AiSuggestion,
): boolean {
  if (!mapping || !suggestion) return false;

  if (mapping.type === 'custom') {
    return !!suggestion.suggest_custom
      && !suggestion.property_name
      && mapping.object_type === suggestion.object_type
      && getCrmMappingPropertyName(mapping) === suggestion.suggested_custom_name;
  }

  if (!suggestion.property_name) return false;

  return mapping.type === 'existing'
    && mapping.object_type === suggestion.object_type
    && getCrmMappingPropertyName(mapping) === suggestion.property_name;
}

export function resolveDuplicateCrmExportKeys(fields: CrmMappingField[]): CrmMappingField[] {
  const nextFields = fields.map((field) => ({
    ...field,
    metadata: { ...(field.metadata || {}) },
  }));
  const duplicateGroups = duplicateGroupsFor(nextFields);

  if (duplicateGroups.size === 0) return nextFields;

  const contextCandidatesByIndex = contextCandidatesFor(nextFields);
  const reservedKeysByScope = reservedKeysFor(nextFields, duplicateGroups);

  duplicateGroups.forEach((entries) => {
    const reservedKeys = reservedKeysByScope.get(entries[0]?.scope || 'contact') || new Set<string>();

    entries.forEach((entry) => {
      const contextualRoots = contextCandidatesByIndex[entry.index].map((suffix) => `${entry.baseKey}_${suffix}`);
      const preferredRoot = contextualRoots[0] || entry.baseKey;

      let selectedKey = preferredRoot;
      if (reservedKeys.has(normalizeScopedExportKey(selectedKey))) {
        selectedKey = nextNumericKey(preferredRoot, reservedKeys);
      }

      reservedKeys.add(normalizeScopedExportKey(selectedKey));
      nextFields[entry.index].metadata = {
        ...(nextFields[entry.index].metadata || {}),
        export_key: selectedKey,
      };
    });

    reservedKeysByScope.set(entries[0]?.scope || 'contact', reservedKeys);
  });

  return nextFields;
}

export function serializeCrmMappingFields(
  fields: CrmMappingField[],
  mappings: CrmMappings,
  exportKeyOverrides: CrmExportKeyOverrides,
  optionsOverrides: CrmOptionsOverrides,
): CrmMappingField[] {
  const serializedFields = fields.map((field, index) => {
    const fieldKey = getCrmMappingFieldStateKey(field, index);
    const fieldMapping = mappings[fieldKey];
    const metadata = { ...(field.metadata || {}) };

    if (fieldMapping && Object.keys(fieldMapping).length > 0) {
      metadata.crm_mapping = fieldMapping;
    } else {
      delete metadata.crm_mapping;
    }

    if (exportKeyOverrides[fieldKey]) {
      metadata.export_key = exportKeyOverrides[fieldKey];
    }

    if (optionsOverrides[fieldKey]) {
      metadata.options = [...optionsOverrides[fieldKey]];
    }

    return {
      ...field,
      metadata,
    };
  });

  return resolveDuplicateCrmExportKeys(serializedFields);
}

function duplicateGroupsFor(fields: CrmMappingField[]): Map<string, DuplicateExportKeyEntry[]> {
  const groupedEntries = new Map<string, DuplicateExportKeyEntry[]>();

  fields.forEach((field, index) => {
    if (isLayoutFieldType(field.field_type)) return;

    const scope = crmScopeForField(field);
    const effectiveKey = effectiveExportKeyForField(field, index);
    const normalizedKey = normalizeScopedExportKey(effectiveKey);
    if (!normalizedKey) return;

    const groupKey = `${scope}:${normalizedKey}`;
    const entries = groupedEntries.get(groupKey) || [];
    entries.push({
      field,
      index,
      baseKey: exportKeyBaseForField(field, index),
      scope,
    });
    groupedEntries.set(groupKey, entries);
  });

  return new Map(Array.from(groupedEntries.entries()).filter(([, entries]) => entries.length > 1));
}

function contextCandidatesFor(fields: CrmMappingField[]): Record<number, string[]> {
  let sectionKey: string | null = null;
  let subtitleKey: string | null = null;

  return fields.reduce<Record<number, string[]>>((memo, field, index) => {
    const label = field.label?.toString().trim() || '';
    switch (field.field_type) {
      case 'section':
        sectionKey = slugifyExportKey(label) || null;
        subtitleKey = null;
        break;
      case 'subtitle':
        subtitleKey = slugifyExportKey(label) || null;
        break;
      default:
        memo[index] = [
          [sectionKey, subtitleKey].filter(Boolean).join('_'),
          subtitleKey,
          sectionKey,
        ].filter((value, position, array): value is string => !!value && array.indexOf(value) === position);
        break;
    }

    return memo;
  }, {});
}

function reservedKeysFor(
  fields: CrmMappingField[],
  duplicateGroups: Map<string, DuplicateExportKeyEntry[]>,
): Map<string, Set<string>> {
  const duplicateKeys = new Set(duplicateGroups.keys());
  const reservedByScope = new Map<string, Set<string>>();

  fields.forEach((field, index) => {
    if (isLayoutFieldType(field.field_type)) return;

    const scope = crmScopeForField(field);
    const normalizedKey = normalizeScopedExportKey(effectiveExportKeyForField(field, index));
    if (!normalizedKey) return;

    if (duplicateKeys.has(`${scope}:${normalizedKey}`)) return;

    const reservedKeys = reservedByScope.get(scope) || new Set<string>();
    reservedKeys.add(normalizedKey);
    reservedByScope.set(scope, reservedKeys);
  });

  return reservedByScope;
}

function nextNumericKey(rootKey: string, reservedKeys: Set<string>): string {
  let suffix = 2;

  while (reservedKeys.has(normalizeScopedExportKey(`${rootKey}_${suffix}`))) {
    suffix += 1;
  }

  return `${rootKey}_${suffix}`;
}

function exportKeyBaseForField(field: CrmMappingField, index: number): string {
  return slugifyExportKey(effectiveExportKeyForField(field, index)) || `field_${index + 1}`;
}

function buildAiAutoMapField(field: CrmMappingField, index: number): CrmAiAutoMapField {
  const metadata = buildAiAutoMapMetadata(field.metadata);

  return {
    id: getFieldIdentityKey(field, index),
    label: field.label || String(field.id ?? `Field ${index + 1}`),
    field_type: field.field_type,
    required: !!field.required,
    position: field.position ?? index + 1,
    ...(metadata ? { metadata } : {}),
  };
}

function effectiveExportKeyForField(field: CrmMappingField, index: number): string {
  const explicit = field.metadata?.export_key?.toString().trim();
  if (explicit) return explicit;

  const label = field.label?.toString().trim();
  if (label) return label;

  return `field_${field.id ?? field.position ?? index + 1}`;
}

function crmScopeForField(field: CrmMappingField): string {
  const crmMapping = field.metadata?.crm_mapping;
  if (!crmMapping || typeof crmMapping !== 'object') return 'contact';

  const objectType = Object.values(crmMapping)
    .map((mapping: any) => mapping?.object_type?.toString().trim())
    .find((value) => !!value);

  return objectType || 'contact';
}

function normalizeScopedExportKey(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return '';

  const normalized = trimmed
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

  return normalized || trimmed.toLowerCase();
}

function slugifyExportKey(value: string): string {
  return normalizeScopedExportKey(value);
}

function buildAiAutoMapMetadata(metadata?: Record<string, any>): CrmAiAutoMapField['metadata'] | undefined {
  if (!metadata || typeof metadata !== 'object') return undefined;

  const nextMetadata: NonNullable<CrmAiAutoMapField['metadata']> = {};
  const exportKey = metadata.export_key?.toString().trim();
  if (exportKey) {
    nextMetadata.export_key = exportKey;
  }

  if (Array.isArray(metadata.options)) {
    nextMetadata.options = metadata.options.map((option) => String(option));
  }

  if (metadata.allow_multiple !== undefined) {
    nextMetadata.allow_multiple = Boolean(metadata.allow_multiple);
  }

  return Object.keys(nextMetadata).length > 0 ? nextMetadata : undefined;
}

function nextCustomPropertyName(
  mappings: CrmMappings,
  provider: string,
  objectType: string,
  suggestedName: string,
): string {
  const baseName = slugifyExportKey(suggestedName) || 'custom_field';
  const usedNames = new Set(
    Object.values(mappings)
      .map((providerMap) => providerMap?.[provider])
      .filter((mapping): mapping is CrmMappingValue => !!mapping && mapping.object_type === objectType)
      .map((mapping) => getCrmMappingPropertyName(mapping))
      .filter((name): name is string => name.length > 0),
  );

  if (!usedNames.has(baseName)) return baseName;

  let suffix = 2;
  while (usedNames.has(`${baseName}_${suffix}`)) {
    suffix += 1;
  }

  return `${baseName}_${suffix}`;
}

function defaultCustomPropertyName(field?: CrmMappingField, index = 0): string {
  if (!field) return `custom_field_${index + 1}`;

  return slugifyExportKey(effectiveExportKeyForField(field, index)) || `custom_field_${index + 1}`;
}

function isLayoutFieldType(fieldType?: string | null): boolean {
  return LAYOUT_FIELD_TYPES.has(String(fieldType || ''));
}