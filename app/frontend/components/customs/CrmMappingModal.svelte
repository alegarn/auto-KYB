<script lang="ts">
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
    
    if (value === '__custom__') {
      mappings[fieldId][provider] = {
        type: 'custom',
        property_name: '' // Will be generated or asked later, keeping it simple here
      };
    } else if (value === '') {
      delete mappings[fieldId][provider];
    } else {
      mappings[fieldId][provider] = {
        type: 'existing',
        property_name: value
      };
    }
  }
</script>

{#if open}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 overflow-y-auto">
    <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl flex flex-col max-h-[90vh]">
      <!-- Header -->
      <div class="px-6 py-4 border-b flex justify-between items-center">
        <h2 class="text-xl font-semibold text-gray-800">CRM Field Mapping</h2>
        <button onclick={close} class="text-gray-500 hover:text-gray-700" aria-label="Close modal">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Body -->
      <div class="p-6 overflow-y-auto flex-1">
        {#if Object.keys(crmProperties).length === 0}
          <div class="p-4 bg-yellow-50 text-yellow-800 rounded-md">
            No active CRM connection found or fetching properties...
          </div>
        {:else}
          {#each Object.entries(crmProperties) as [provider, properties]}
            <div class="mb-8">
              <h3 class="text-lg font-medium mb-4 capitalize">{provider} Integration</h3>
              
              {#if properties && properties.length > 0}
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
                            {field.label || field.name || 'Unnamed Field'}
                            <span class="text-xs text-gray-500 ml-2">({field.kind})</span>
                          </td>
                          <td class="px-4 py-3">
                            {#if true}
                              {@const currentValue = mappings[field.id]?.[provider]?.type === 'custom' 
                                ? '__custom__' 
                                : mappings[field.id]?.[provider]?.property_name || ''}
                              
                              <select 
                                class="w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm p-2 border"
                                value={currentValue}
                                onchange={(e) => updateMapping(field.id, provider, e.currentTarget.value)}
                              >
                                <option value="">-- Do not map --</option>
                                <option value="__custom__" class="font-semibold text-blue-600">+ Create as Custom Property</option>
                                <optgroup label="Existing Properties">
                                  {#each properties as prop}
                                    <option value={prop.name}>{prop.label || prop.name}</option>
                                  {/each}
                                </optgroup>
                              </select>
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
