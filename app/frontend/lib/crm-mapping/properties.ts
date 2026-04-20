import { isHubSpotCompatible } from '../crm/hubspot-compat';
import { areTypesCompatible, toCrmKey } from '../crm-utils';

import { getCrmMappingPropertyName } from './draft';
import type { CrmInventoryProperty, CrmMappings, CrmProviderProperties, CrmMappingField } from './types';

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

        return [toCrmKey(mapping.object_type, propertyName)];
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
