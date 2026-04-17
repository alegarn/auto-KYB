import { fromCrmKey, getFieldIdentityKey } from '../crm-utils';

import type { CrmAiAutoMapField, CrmMappingField, CrmMappingValue, CrmMappings } from './types';

const LAYOUT_FIELD_TYPES = new Set(['section', 'subtitle', 'static_text', 'separator', 'logo']);

export function isLayoutFieldType(fieldType?: string | null): boolean {
  return LAYOUT_FIELD_TYPES.has(String(fieldType || ''));
}

export function getCrmPropertyNameFromKey(propertyName?: string | null): string {
  if (!propertyName) return '';
  return fromCrmKey(propertyName).propertyName;
}

export function normalizeScopedExportKey(value: string): string {
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

export function slugifyExportKey(value: string): string {
  return normalizeScopedExportKey(value);
}

export function getEffectiveExportKeyForField(field: CrmMappingField, index: number): string {
  const explicit = field.metadata?.export_key?.toString().trim();
  if (explicit) return explicit;

  const label = field.label?.toString().trim();
  if (label) return label;

  return `field_${field.id ?? field.position ?? index + 1}`;
}

export function buildAiAutoMapMetadata(
  metadata?: Record<string, any>,
): CrmAiAutoMapField['metadata'] | undefined {
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

export function buildAiAutoMapField(field: CrmMappingField, index: number): CrmAiAutoMapField {
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

export function getDefaultCustomPropertyName(field?: CrmMappingField, index = 0): string {
  if (!field) return `custom_field_${index + 1}`;

  return slugifyExportKey(getEffectiveExportKeyForField(field, index)) || `custom_field_${index + 1}`;
}

export function getNextCustomPropertyName(
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
      .map((mapping) => getCrmPropertyNameFromKey(mapping.property_name))
      .filter((name): name is string => name.length > 0),
  );

  if (!usedNames.has(baseName)) return baseName;

  let suffix = 2;
  while (usedNames.has(`${baseName}_${suffix}`)) {
    suffix += 1;
  }

  return `${baseName}_${suffix}`;
}
