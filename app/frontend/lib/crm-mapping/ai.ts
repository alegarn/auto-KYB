import type { AiSuggestion } from '../crm/ai-auto-map';
import { isPseudoFileAction } from '../crm-utils';

import { getCrmMappingFieldStateKey, getCrmMappingPropertyName } from './draft';
import { buildAiAutoMapField, getCrmPropertyNameFromKey, isLayoutFieldType } from './shared';
import type {
  CrmAiAutoMapRequest,
  CrmAiAutoMapRequestOptions,
  CrmMappingIndexedField,
  CrmMappingValue,
  CrmMappings,
} from './types';

export const DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE = 12;

export function buildAiLoadingFieldKeySets(
  aiPendingFieldKeys: Record<string, string[]>,
): Record<string, Set<string>> {
  return Object.fromEntries(
    Object.entries(aiPendingFieldKeys).map(([provider, fieldKeys]) => [provider, new Set(fieldKeys)]),
  );
}

export function buildAiAutoMapRequest(
  fields: CrmMappingIndexedField[],
  mappings: CrmMappings,
  provider: string,
  fieldIdToStateKey: Record<string, string>,
  options: CrmAiAutoMapRequestOptions = {},
): CrmAiAutoMapRequest {
  const allUnmappedFields = fields
    .filter(({ field }) => !isLayoutFieldType(field.field_type))
    .filter(({ field, index }) => !mappings[getCrmMappingFieldStateKey(field, index)]?.[provider])
    .map(({ field, index }) => buildAiAutoMapField(field, index));

  const selectedFieldIds = normalizeAiAutoMapFieldIds(options.fieldIds);
  const selectedUnmappedFields = selectedFieldIds.length > 0
    ? allUnmappedFields.filter(({ id }) => selectedFieldIds.includes(String(id)))
    : allUnmappedFields.slice(0, normalizeAiAutoMapBatchSize(options.batchSize));

  const contextualFieldIds = new Set(selectedUnmappedFields.map(({ id }) => String(id)));
  const draftFields = selectedUnmappedFields.length === 0
    ? []
    : fields
        .filter(({ field, index }) => {
          return isLayoutFieldType(field.field_type) || contextualFieldIds.has(buildAiAutoMapField(field, index).id);
        })
        .map(({ field, index }) => buildAiAutoMapField(field, index));

  const alreadyMapped = Object.values(mappings)
    .map((providerMap) => providerMap?.[provider])
    .filter((mapping): mapping is CrmMappingValue => mapping?.type === 'existing' && !!mapping.property_name)
    .filter((mapping) => !isPseudoFileAction(getCrmMappingPropertyName(mapping)))
    .map((mapping) => mapping.property_name)
    .filter((propertyName): propertyName is string => propertyName.length > 0);

  return {
    unmappedFields: selectedUnmappedFields,
    alreadyMapped,
    pendingFieldKeys: selectedUnmappedFields.map(({ id }) => fieldIdToStateKey[String(id)] || String(id)),
    draftFields,
    totalUnmappedCount: allUnmappedFields.length,
    allUnmappedFieldIds: allUnmappedFields.map(({ id }) => String(id)),
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
    && getCrmPropertyNameFromKey(mapping.property_name) === suggestion.property_name;
}

function normalizeAiAutoMapFieldIds(fieldIds?: string[]): string[] {
  const uniqueFieldIds = new Set<string>();

  for (const fieldId of fieldIds || []) {
    const normalized = String(fieldId || '').trim();
    if (!normalized) continue;

    uniqueFieldIds.add(normalized);
  }

  return Array.from(uniqueFieldIds);
}

function normalizeAiAutoMapBatchSize(batchSize?: number): number {
  if (!Number.isFinite(batchSize) || (batchSize || 0) <= 0) {
    return DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE;
  }

  return Math.max(1, Math.floor(batchSize as number));
}
