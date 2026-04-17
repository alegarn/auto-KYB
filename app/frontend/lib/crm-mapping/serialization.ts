import { getCrmMappingFieldStateKey } from './draft';
import {
  getEffectiveExportKeyForField,
  isLayoutFieldType,
  normalizeScopedExportKey,
  slugifyExportKey,
} from './shared';
import type {
  CrmMappingField,
  CrmMappings,
  CrmExportKeyOverrides,
  CrmOptionsOverrides,
} from './types';

interface DuplicateExportKeyEntry {
  field: CrmMappingField;
  index: number;
  baseKey: string;
  scope: string;
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
    const effectiveKey = getEffectiveExportKeyForField(field, index);
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
    const normalizedKey = normalizeScopedExportKey(getEffectiveExportKeyForField(field, index));
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
  return slugifyExportKey(getEffectiveExportKeyForField(field, index)) || `field_${index + 1}`;
}

function crmScopeForField(field: CrmMappingField): string {
  const crmMapping = field.metadata?.crm_mapping;
  if (!crmMapping || typeof crmMapping !== 'object') return 'contact';

  const objectType = Object.values(crmMapping)
    .map((mapping: any) => mapping?.object_type?.toString().trim())
    .find((value) => !!value);

  return objectType || 'contact';
}
