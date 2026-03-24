<script lang="ts">
  import { areTypesCompatible, getFieldDataType, analyzeMappings, getProviderFileActions, toCrmKey, fromCrmKey, CRM_KEY_SEP, type CrmExportSummary, type CrmObjectStatus } from '../../lib/crm-utils';
  import { isLayoutField } from './form-builder/types';
  import { Select } from "bits-ui";
  import { Check, ChevronsUpDown, Search, Loader2 } from "@lucide/svelte";
  import { cn } from "../../lib/utils";

  // Props
  let { 
    open = $bindable(false), 
    form = {}, 
    crmProperties = {}, 
    loadingProperties = false, // Add loading prop
    fields = [],
    onsave,
    ontestcrm,
    testingCrm = false,
    testCrmSuccess = false
  } = $props();

  // Local state for mapping
  // Maps a stable per-row modal key to provider mappings so unsaved fields do not collide on undefined ids.
  let mappings = $state<Record<string, Record<string, any>>>({});
  let exportKeyOverrides = $state<Record<string, string>>({});
  let fieldSearch = $state<Record<string, string>>({});
  const dataFields = $derived(fields.map((field, index) => ({ field, index })).filter(({ field }) => !isLayoutField(field.field_type)));

  function getFieldStateKey(field: any, index: number) {
    return field.id ? `id:${field.id}` : `draft:${index}`;
  }

  // Initialize mappings from fields metadata if it exists
  $effect(() => {
    if (open) {
      const newMappings: Record<string, Record<string, any>> = {};
      dataFields.forEach(({ field, index }) => {
        const providerMap: Record<string, any> = {};
        if (field.metadata?.crm_mapping) {
          for (const [prov, rawMapping] of Object.entries(field.metadata.crm_mapping as Record<string, any>)) {
            const m = { ...rawMapping };
            // Normalize legacy data: add compound key prefix if missing
            if (m.property_name && m.object_type && !m.property_name.includes(CRM_KEY_SEP)) {
              m.property_name = toCrmKey(m.object_type, m.property_name);
            }
            providerMap[prov] = m;
          }
        }
        newMappings[getFieldStateKey(field, index)] = providerMap;
      });
      mappings = newMappings;
      exportKeyOverrides = {};
      fieldSearch = {};
    }
  });

  function getFilteredProperties(providerProperties: any[], search: string) {
    if (!search) return providerProperties;
    const s = search.toLowerCase();
    return providerProperties.filter(p => 
      (p.label || '').toLowerCase().includes(s) || 
      (p.name || '').toLowerCase().includes(s)
    );
  }

  function handleSave() {
    onsave?.({ fields: getUpdatedFields() });
    open = false;
  }

  function getUpdatedFields() {
    return fields.map((field, index) => {
      const fieldKey = getFieldStateKey(field, index);
      const fieldMapping = mappings[fieldKey];
      const metadata = { ...field.metadata };
      
      if (fieldMapping && Object.keys(fieldMapping).length > 0) {
        metadata.crm_mapping = fieldMapping;
      } else {
        delete metadata.crm_mapping;
      }

      if (exportKeyOverrides[fieldKey]) {
        metadata.export_key = exportKeyOverrides[fieldKey];
      }
      
      return {
        ...field,
        metadata
      };
    });
  }

  function handleTest() {
    ontestcrm?.(getUpdatedFields());
  }

  function close() {
    open = false;
  }

  function getExportKey(field: any, index: number) {
    return exportKeyOverrides[getFieldStateKey(field, index)] ?? field.metadata?.export_key;
  }

  // Helper to update mapping for a specific field and provider
  function updateMapping(fieldKey: string, provider: string, value: string) {
    if (!mappings[fieldKey]) {
      mappings[fieldKey] = {};
    }
    
    if (value === '__custom_contact__') {
      mappings[fieldKey][provider] = {
        type: 'custom',
        object_type: 'contact',
        property_name: '' // Will be generated or asked later, keeping it simple here
      };
    } else if (value === '__custom_company__') {
      mappings[fieldKey][provider] = {
        type: 'custom',
        object_type: 'company',
        property_name: ''
      };
    } else if (value === '') {
      delete mappings[fieldKey][provider];
    } else {
      // Format from Select is "object_type:property_name" (single colon)
      const [object_type, ...rest] = value.split(':');
      const rawPropertyName = rest.join(':');
      
      mappings[fieldKey][provider] = {
        type: 'existing',
        object_type,
        property_name: toCrmKey(object_type, rawPropertyName),
        read_only: (crmProperties[provider][object_type] || []).find((p: any) => p.name === rawPropertyName)?.read_only || false
      };
    }
  }

  function syncExportKey(fieldKey: string, provider: string) {
    const mapping = mappings[fieldKey]?.[provider];
    if (mapping?.property_name) {
      // Strip compound key prefix — export_key is user-facing (CSV/JSON)
      exportKeyOverrides = {
        ...exportKeyOverrides,
        [fieldKey]: fromCrmKey(mapping.property_name).propertyName,
      };
    }
  }

  // Reactive summary: what CRM records will be created per provider
  let summaries = $derived.by(() => {
    const result: Record<string, CrmExportSummary> = {};
    for (const provider of Object.keys(crmProperties)) {
      result[provider] = analyzeMappings(mappings, provider);
    }
    return result;
  });
</script>

{#if open}
  <div data-testid="crm-mapping-modal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 overflow-y-auto">
    <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl flex flex-col max-h-[90vh]">
      <!-- Header -->
      <div class="px-6 py-4 border-b flex justify-between items-center">
        <h2 class="text-xl font-semibold text-gray-800">CRM Field Mapping</h2>
        <div class="flex gap-4 items-center">
          <button 
            type="button" 
            data-testid="auto-map-fields"
            class="text-sm px-3 py-1.5 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 rounded border border-indigo-200" 
            onclick={async () => {
              const { autoMapFields } = await import('../../lib/crm-utils');
              const autoMapped = autoMapFields(fields, crmProperties);
              
              // Build a lookup from raw field.id to modal state key
              const fieldIdToStateKey: Record<string, string> = {};
              dataFields.forEach(({ field, index }) => {
                if (field.id) fieldIdToStateKey[field.id] = getFieldStateKey(field, index);
              });
              
              // Merge auto-mappings with user's current ones, preferring existing if already set
              const merged = Object.fromEntries(
                Object.entries(mappings).map(([fieldId, providerMap]) => [fieldId, { ...providerMap }])
              );
              for (const [rawFieldId, providerMap] of Object.entries(autoMapped)) {
                const stateKey = fieldIdToStateKey[rawFieldId] || rawFieldId;
                if (!merged[stateKey]) merged[stateKey] = {};
                for (const [provider, mapping] of Object.entries(providerMap)) {
                  if (!merged[stateKey][provider]) {
                    merged[stateKey][provider] = mapping;
                  }
                }
              }
              mappings = merged;
            }}
          >
            Auto-Map Fields
          </button>
          <button onclick={close} class="text-gray-500 hover:text-gray-700" aria-label="Close modal">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Body -->
      <div class="p-6 overflow-y-auto flex-1">
        {#if loadingProperties}
          <div class="flex flex-col items-center justify-center py-12 gap-3 text-gray-500">
            <Loader2 class="h-8 w-8 animate-spin text-indigo-500" />
            <p class="text-sm font-medium">Fetching CRM properties...</p>
          </div>
        {:else if Object.keys(crmProperties).length === 0}
          <div class="p-4 bg-yellow-50 text-yellow-800 rounded-md">
            No active CRM connection found. Please connect your HubSpot or Salesforce account in settings.
          </div>
        {:else}
          {#each Object.entries(crmProperties) as [provider, properties]}
            <div class="mb-8" data-provider={provider}>
              <h3 class="text-lg font-medium mb-4 capitalize">{provider} Integration</h3>
              
              <!-- CRM Export Summary Banner -->
              {#if summaries[provider]}
                {@const summary = summaries[provider]}
                <div class="mb-4 rounded-lg border bg-gray-50 p-4">
                  <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Export Preview</p>
                  <div class="flex flex-wrap gap-3">
                    <!-- Contact Status -->
                    <div class="flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium {summary.contact.status === 'ready' ? 'bg-green-50 text-green-800 border border-green-200' : 'bg-gray-100 text-gray-500 border border-gray-200'}">
                      {#if summary.contact.status === 'ready'}
                        <svg class="w-4 h-4 text-green-600 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                        <span>Contact <span class="font-normal">({summary.contact.count} field{summary.contact.count > 1 ? 's' : ''})</span></span>
                      {:else}
                        <svg class="w-4 h-4 text-gray-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                        <span>No contact</span>
                      {/if}
                    </div>

                    <!-- Company Status -->
                    <div class="flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium {summary.company.status === 'ready' ? 'bg-green-50 text-green-800 border border-green-200' : summary.company.status === 'warning' ? 'bg-amber-50 text-amber-800 border border-amber-200' : 'bg-gray-100 text-gray-500 border border-gray-200'}">
                      {#if summary.company.status === 'ready'}
                        <svg class="w-4 h-4 text-green-600 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                        <span>Company <span class="font-normal">({summary.company.count} field{summary.company.count > 1 ? 's' : ''})</span></span>
                      {:else if summary.company.status === 'warning'}
                        <svg class="w-4 h-4 text-amber-600 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                        <span>Company <span class="font-normal">(incomplete)</span></span>
                      {:else}
                        <svg class="w-4 h-4 text-gray-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                        <span>No company</span>
                      {/if}
                    </div>

                    <!-- Association Status -->
                    <div class="flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium {summary.association.status === 'ready' ? 'bg-green-50 text-green-800 border border-green-200' : summary.association.status === 'warning' ? 'bg-amber-50 text-amber-800 border border-amber-200' : 'bg-gray-100 text-gray-500 border border-gray-200'}">
                      {#if summary.association.status === 'ready'}
                        <svg class="w-4 h-4 text-green-600 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" /></svg>
                        <span>Linked</span>
                      {:else if summary.association.status === 'warning'}
                        <svg class="w-4 h-4 text-amber-600 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" /></svg>
                        <span>Link uncertain</span>
                      {:else}
                        <svg class="w-4 h-4 text-gray-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" /></svg>
                        <span>No link</span>
                      {/if}
                    </div>
                  </div>

                  <!-- Warning detail for incomplete company -->
                  {#if summary.company.status === 'warning' && summary.company.missingIdentifiers}
                    <div class="mt-3 flex items-start gap-2 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-md px-3 py-2">
                      <svg class="w-4 h-4 text-amber-500 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                      <p>
                        You have {summary.company.count} company field{summary.company.count > 1 ? 's' : ''} mapped, but the CRM requires at least one identifier property
                        ({#each summary.company.missingIdentifiers as identifier, i}
                          <strong>{identifier}</strong>{i < summary.company.missingIdentifiers.length - 1 ? ' or ' : ''}
                        {/each}) to create a Company record. 
                        Without it, company data won't be exported.
                      </p>
                    </div>
                  {/if}
                </div>
              {/if}
              
              {#if properties && ((properties.contact && properties.contact.length > 0) || (properties.company && properties.company.length > 0))}
                <div class="overflow-x-auto border rounded-lg">
                  <table class="w-full text-left text-sm text-gray-600">
                    <thead class="bg-gray-50 border-b">
                      <tr>
                        <th class="px-4 py-3 font-medium">App Form Field</th>
                        <th class="px-4 py-3 font-medium">Mapped to CRM Property</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y">
                      {#each dataFields as { field, index }}
                        <tr class="hover:bg-gray-50">
                          <td class="px-4 py-3 font-medium text-gray-900">
                            <div class="flex flex-col">
                              <span>{field.label || field.id || 'Unnamed Field'}</span>
                              <div class="flex items-center gap-1.5 mt-0.5">
                                <span class="text-[10px] text-gray-500 uppercase font-semibold">Type: {getFieldDataType(field.field_type)}</span>
                                {#if getExportKey(field, index)}
                                  <span class="text-[10px] text-indigo-100 bg-indigo-600 px-1 rounded-sm font-mono tracking-tight" title="Data Export Key: {getExportKey(field, index)}">Key: {getExportKey(field, index)}</span>
                                {/if}
                              </div>
                            </div>
                          </td>
                          <td class="px-4 py-3">
                            {#if true}
                              {@const fieldKey = getFieldStateKey(field, index)}
                              {@const mapping = mappings[fieldKey]?.[provider]}
                              {@const rawPropName = mapping?.property_name ? fromCrmKey(mapping.property_name).propertyName : ''}
                              {@const currentValue = mapping?.type === 'custom' 
                                ? `__custom_${mapping.object_type}__` 
                                : rawPropName ? `${mapping.object_type}:${rawPropName}` : ''}
                              
                              {@const selectedProp = mapping?.type === 'existing' 
                                ? (properties[mapping.object_type] || []).find((p: any) => p.name === rawPropName) 
                                : null}
                              {@const isCompatible = !selectedProp || areTypesCompatible(field.field_type, selectedProp.type)}
                              {@const providerFileActions = getProviderFileActions(provider)}
                              {@const selectedFileAction = providerFileActions.find(a => a.value === currentValue)}

                              <div class="space-y-1">
                                <Select.Root 
                                  type="single"
                                  bind:value={() => currentValue, (v) => updateMapping(fieldKey, provider, v)}
                                  onOpenChange={(isOpen: boolean) => { if (!isOpen) fieldSearch[`${fieldKey}-${provider}`] = ''; }}
                                >
                                  <Select.Trigger
                                    class={cn(
                                      "flex h-9 w-full items-center justify-between rounded-md border border-gray-300 bg-white px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500",
                                      !isCompatible && "border-red-300 ring-1 ring-red-300"
                                    )}
                                    data-testid={`crm-mapping-select-${fieldKey}-${provider}`}
                                  >
                                    {#if currentValue === "__custom_contact__"}
                                      + Create as Custom Contact Property
                                    {:else if selectedFileAction}
                                      {selectedFileAction.label}
                                    {:else}
                                      {selectedProp ? `${selectedProp.label || selectedProp.name} (${selectedProp.type})` : "-- Do not map --"}
                                    {/if}
                                    <ChevronsUpDown class="h-4 w-4 opacity-50" />
                                  </Select.Trigger>
                                  <Select.Content 
                                    class="z-50 min-w-[8rem] overflow-hidden rounded-md border bg-white p-1 text-gray-950 shadow-md animate-in fade-in-80"
                                    data-slot="select-content"
                                  >
                                    <div class="flex items-center border-b px-3 mb-1 bg-white sticky top-0 z-10">
                                      <Search class="mr-2 h-4 w-4 shrink-0 opacity-50" />
                                      <input 
                                        class="flex h-10 w-full rounded-md bg-transparent py-3 text-sm outline-none placeholder:text-gray-500 disabled:cursor-not-allowed disabled:opacity-50"
                                        placeholder={`Filter ${provider} properties...`}
                                        value={fieldSearch[`${fieldKey}-${provider}`] || ''}
                                        oninput={(e) => fieldSearch[`${fieldKey}-${provider}`] = e.currentTarget.value}
                                        onkeydown={(e) => {
                                          if (e.key === 'Space') e.stopPropagation();
                                        }}
                                      />
                                    </div>
                                    <div class="max-h-60 overflow-y-auto">
                                      <Select.Item
                                        value=""
                                        class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                        data-slot="select-item"
                                      >
                                        -- Do not map --
                                      </Select.Item>
                                      <Select.Item
                                        value="__custom_contact__"
                                        class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm font-semibold text-blue-600 outline-none focus:bg-blue-50 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                        data-slot="select-item"
                                      >
                                        + Create as Custom Contact Property
                                      </Select.Item>
                                      
                                      {#if getFieldDataType(field.field_type) === 'file' && providerFileActions.length > 0}
                                        <div class="px-2 py-1.5 text-xs font-semibold text-gray-400">File Actions</div>
                                        {#each providerFileActions as fileAction}
                                          <Select.Item
                                            value={fileAction.value}
                                            class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                            data-slot="select-item"
                                          >
                                            {fileAction.label}
                                          </Select.Item>
                                        {/each}
                                      {/if}

                                      <div class="px-2 py-1.5 text-xs font-semibold text-gray-400">Existing Contact Properties</div>
                                      {#each getFilteredProperties(properties.contact || [], fieldSearch[`${fieldKey}-${provider}`]) as prop}
                                        <Select.Item
                                          value={`contact:${prop.name}`}
                                          disabled={prop.read_only}
                                          class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                          data-slot="select-item"
                                        >
                                          <span class="flex-1 truncate">{prop.label || prop.name} {prop.read_only ? '(Read Only)' : ''}</span>
                                          <span class="ml-2 text-[10px] text-gray-400 uppercase tracking-tighter">{prop.type}</span>
                                        </Select.Item>
                                      {/each}

                                      <div class="px-2 py-1.5 text-xs font-semibold text-gray-400">Existing Company Properties</div>
                                      {#each getFilteredProperties(properties.company || [], fieldSearch[`${fieldKey}-${provider}`]) as prop}
                                        <Select.Item
                                          value={`company:${prop.name}`}
                                          disabled={prop.read_only}
                                          class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                          data-slot="select-item"
                                        >
                                          <span class="flex-1 truncate">{prop.label || prop.name} {prop.read_only ? '(Read Only)' : ''}</span>
                                          <span class="ml-2 text-[10px] text-gray-400 uppercase tracking-tighter">{prop.type}</span>
                                        </Select.Item>
                                      {/each}
                                    </div>
                                  </Select.Content>
                                </Select.Root>
                                
                                {#if !isCompatible}
                                  <p data-testid={`type-mismatch-${field.id}-${provider}`} class="text-[10px] text-red-600 font-medium">
                                    Type mismatch: {getFieldDataType(field.field_type)} vs {selectedProp.type}. This might lead to data issues.
                                  </p>
                                {/if}

                                {#if selectedProp && getExportKey(field, index) !== selectedProp.name}
                                  <div class="flex items-center justify-between">
                                    <p class="text-[10px] text-amber-600 font-medium">
                                      Key mismatch: export key ({getExportKey(field, index) || 'label'}) != {selectedProp.name}
                                    </p>
                                    <button 
                                      type="button"
                                      onclick={() => syncExportKey(fieldKey, provider)}
                                      class="text-[9px] bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded border border-amber-200 hover:bg-amber-100 transition-colors"
                                      title="Update Data Export Key to match CRM property name"
                                    >
                                      Align Key
                                    </button>
                                  </div>
                                {/if}
                              </div>
                            {/if}
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              {:else}
                 <p class="text-gray-500 italic">No properties available for {provider}.</p>
              {/if}
            </div>
          {/each}
        {/if}
      </div>

      <!-- Footer -->
      <div class="px-6 py-4 border-t bg-gray-50 flex justify-end items-center gap-3 rounded-b-lg">
        {#if testCrmSuccess}
          <span class="text-green-600 text-sm font-medium mr-auto">✓ Test export sent successfully!</span>
        {/if}
        
        <button 
          onclick={handleTest}
          class="px-4 py-2 border border-blue-300 text-blue-700 rounded-md hover:bg-blue-50 font-medium disabled:opacity-50"
          disabled={testingCrm || Object.keys(crmProperties).length === 0}
        >
          {testingCrm ? 'Sending Test...' : 'Send Test Data'}
        </button>

        <button 
          onclick={close}
          class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-100 font-medium"
        >
          Cancel
        </button>
        <button 
          onclick={handleSave}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium disabled:opacity-50"
          disabled={Object.keys(crmProperties).length === 0}
        >
          Save Mapping
        </button>
      </div>
    </div>
  </div>
{/if}
