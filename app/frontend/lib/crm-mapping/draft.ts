import type { AiSuggestion } from '../crm/ai-auto-map';
import { getFieldIdentityKey, isPseudoFileAction, toCrmKey } from '../crm-utils';

import {
  getCrmPropertyNameFromKey,
  getDefaultCustomPropertyName,
  getNextCustomPropertyName,
} from './shared';
import type {
  CrmExportKeyOverrides,
  CrmMappingDraftState,
  CrmMappingField,
  CrmMappingIndexedField,
  CrmMappings,
  CrmOptionsOverrides,
  CrmMappingValue,
} from './types';

function shouldAlignExportKeyFromMapping(mapping?: CrmMappingValue | null): boolean {
  const propertyName = getCrmMappingPropertyName(mapping);
  return propertyName.length > 0 && !isPseudoFileAction(propertyName);
}

function shouldAlignExportKeyFromSuggestion(propertyName?: string | null): boolean {
  return !!propertyName && !isPseudoFileAction(propertyName);
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

export function getCrmMappingFieldStateKey(field: CrmMappingField, index: number): string {
  return field.id !== undefined && field.id !== null ? `id:${field.id}` : `draft:${index}`;
}

export function getCrmMappingPropertyName(mapping?: CrmMappingValue | null): string {
  return getCrmPropertyNameFromKey(mapping?.property_name);
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
    const propertyName = getNextCustomPropertyName(
      nextMappings,
      provider,
      'contact',
      getDefaultCustomPropertyName(field, index),
    );
    nextMappings[fieldKey][provider] = {
      type: 'custom',
      object_type: 'contact',
      property_name: toCrmKey('contact', propertyName),
    };
  } else if (value === '__custom_company__') {
    const propertyName = getNextCustomPropertyName(
      nextMappings,
      provider,
      'company',
      getDefaultCustomPropertyName(field, index),
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
      read_only: providerProperties?.[object_type]?.find((property: any) => property.name === rawPropertyName)?.read_only || false,
    };
  }

  return nextMappings;
}

export function applyCrmExportKeyAlignment(
  exportKeyOverrides: CrmExportKeyOverrides,
  fieldKey: string,
  mapping?: CrmMappingValue,
): CrmExportKeyOverrides {
  if (!shouldAlignExportKeyFromMapping(mapping)) return exportKeyOverrides;

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
        if (!nextExportKeyOverrides[stateKey] && shouldAlignExportKeyFromMapping(mapping as CrmMappingValue)) {
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
      const propertyName = getNextCustomPropertyName(
        nextMappings,
        provider,
        suggestion.object_type,
        suggestion.suggested_custom_name,
      );
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
    if (shouldAlignExportKeyFromSuggestion(suggestion.property_name)) {
      nextExportKeyOverrides[stateKey] = suggestion.property_name;
    }
  }

  return {
    mappings: nextMappings,
    exportKeyOverrides: nextExportKeyOverrides,
    optionsOverrides: {},
  };
}
