<script lang="ts">
  import { areTypesCompatible, getFieldDataType, analyzeMappings, type CrmExportSummary, type CrmObjectStatus } from '../../lib/crm-utils';

  // Props
  let { 
    open = $bindable(false), 
    form = {}, 
    crmProperties = {}, 
    fields = [],
    onsave,
    ontestcrm,
    testingCrm = false,
    testCrmSuccess = false
  } = $props();

  // Local state for mapping
  // maps field.id -> { provider: { type: 'existing' | 'custom', property_name: string } }
  let mappings = $state<Record<string, Record<string, any>>>({});

  // Initialize mappings from fields metadata if it exists
  $effect(() => {
    if (open) {
      const newMappings: Record<string, Record<string, any>> = {};
      fields.forEach(field => {
        newMappings[field.id] = field.metadata?.crm_mapping || {};
      });
      mappings = newMappings;
    }
  });

  function handleSave() {
    // Construct updated fields array with new metadata
    const updatedFields = fields.map(field => {
      const fieldMapping = mappings[field.id];
      if (!fieldMapping || Object.keys(fieldMapping).length === 0) {
        return field;
      }
      return {
        ...field,
        metadata: {
          ...field.metadata,
          crm_mapping: fieldMapping
        }
      };
    });

    onsave?.({ fields: updatedFields });
    open = false;
  }

  function close() {
    open = false;
  }

  // Helper to update mapping for a specific field and provider
  function updateMapping(fieldId: string, provider: string, value: string) {
    if (!mappings[fieldId]) {
      mappings[fieldId] = {};
    }
    
    if (value === '__custom_contact__') {
      mappings[fieldId][provider] = {
        type: 'custom',
        object_type: 'contact',
        property_name: '' // Will be generated or asked later, keeping it simple here
      };
    } else if (value === '__custom_company__') {
      mappings[fieldId][provider] = {
        type: 'custom',
        object_type: 'company',
        property_name: ''
      };
    } else if (value === '') {
      delete mappings[fieldId][provider];
    } else {
      // Format is "object_type:property_name"
      const [object_type, ...rest] = value.split(':');
      const property_name = rest.join(':');
      
      mappings[fieldId][provider] = {
        type: 'existing',
        object_type,
        property_name
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
              
              // Merge auto-mappings with user's current ones, preferring existing if already set
              const merged = { ...mappings };
              for (const [fieldId, providerMap] of Object.entries(autoMapped)) {
                if (!merged[fieldId]) merged[fieldId] = {};
                for (const [provider, mapping] of Object.entries(providerMap)) {
                  if (!merged[fieldId][provider]) {
                    merged[fieldId][provider] = mapping;
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
        {#if Object.keys(crmProperties).length === 0}
          <div class="p-4 bg-yellow-50 text-yellow-800 rounded-md">
            No active CRM connection found or fetching properties...
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
                      {#each fields as field}
                        <tr class="hover:bg-gray-50">
                          <td class="px-4 py-3 font-medium text-gray-900">
                            {field.label || field.id || 'Unnamed Field'}
                            <span class="text-xs text-gray-500 ml-2">({getFieldDataType(field.field_type)})</span>
                          </td>
                          <td class="px-4 py-3">
                            {#if true}
                              {@const mapping = mappings[field.id]?.[provider]}
                              {@const currentValue = mapping?.type === 'custom' 
                                ? `__custom_${mapping.object_type}__` 
                                : mapping?.property_name ? `${mapping.object_type}:${mapping.property_name}` : ''}
                              
                              {@const selectedProp = mapping?.type === 'existing' 
                                ? (properties[mapping.object_type] || []).find((p: any) => p.name === mapping.property_name) 
                                : null}
                              {@const isCompatible = !selectedProp || areTypesCompatible(field.field_type, selectedProp.type)}

                              <div class="space-y-1">
                                <select 
                                  data-field-id={field.id}
                                  data-provider={provider}
                                  class="w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm p-2 border {isCompatible ? '' : 'border-red-300 ring-1 ring-red-300'}"
                                  value={currentValue}
                                  onchange={(e) => updateMapping(field.id, provider, e.currentTarget.value)}
                                >
                                  <option value="">-- Do not map --</option>
                                  <option value="__custom_contact__" class="font-semibold text-blue-600">+ Create as Custom Contact Property</option>
                                  <option value="__custom_company__" class="font-semibold text-blue-600">+ Create as Custom Company Property</option>
                                  
                                  <optgroup label="Existing Contact Properties">
                                    {#each (properties.contact || []) as prop}
                                      <option value={`contact:${prop.name}`}>{prop.label || prop.name} ({prop.type})</option>
                                    {/each}
                                  </optgroup>

                                  <optgroup label="Existing Company Properties">
                                    {#each (properties.company || []) as prop}
                                      <option value={`company:${prop.name}`}>{prop.label || prop.name} ({prop.type})</option>
                                    {/each}
                                  </optgroup>
                                </select>
                                
                                {#if !isCompatible}
                                  <p data-testid={`type-mismatch-${field.id}-${provider}`} class="text-[10px] text-red-600 font-medium">
                                    Type mismatch: {getFieldDataType(field.field_type)} vs {selectedProp.type}. This might lead to data issues.
                                  </p>
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
          onclick={ontestcrm}
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
