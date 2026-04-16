import type { AiSuggestion } from './crm/ai-auto-map';

import { fromCrmKey, getFieldIdentityKey, toCrmKey } from './crm-utils';

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

export interface CrmMappingDraftState {
  mappings: CrmMappings;
  exportKeyOverrides: CrmExportKeyOverrides;
  optionsOverrides: CrmOptionsOverrides;
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

export function applyCrmMappingSelection(
  mappings: CrmMappings,
  fieldKey: string,
  provider: string,
  value: string,
  providerProperties: Record<string, Array<{ name?: string; read_only?: boolean }>> = {},
): CrmMappings {
  const nextMappings: CrmMappings = Object.fromEntries(
    Object.entries(mappings).map(([existingFieldKey, providerMap]) => [existingFieldKey, { ...providerMap }]),
  );

  if (!nextMappings[fieldKey]) {
    nextMappings[fieldKey] = {};
  }

  if (value === '__custom_contact__') {
    nextMappings[fieldKey][provider] = {
      type: 'custom',
      object_type: 'contact',
      property_name: '',
    };
  } else if (value === '__custom_company__') {
    nextMappings[fieldKey][provider] = {
      type: 'custom',
      object_type: 'company',
      property_name: '',
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
    if (!suggestion.property_name) continue;

    const stateKey = fieldIdToStateKey[rawFieldId] || rawFieldId;

    if (!nextMappings[stateKey]) {
      nextMappings[stateKey] = {};
    }

    if (nextMappings[stateKey][provider]) continue;

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

export function serializeCrmMappingFields(
  fields: CrmMappingField[],
  mappings: CrmMappings,
  exportKeyOverrides: CrmExportKeyOverrides,
  optionsOverrides: CrmOptionsOverrides,
): CrmMappingField[] {
  return fields.map((field, index) => {
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
}