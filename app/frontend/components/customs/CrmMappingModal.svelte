<script lang="ts">
  import { onDestroy } from 'svelte';
  import { validate_crm_mapping_form_path } from '@/routes';
  import { Loader2 } from '@lucide/svelte';
  import { analyzeMappings, autoMapFields, type CrmExportSummary } from '../../lib/crm-utils';
  import {
    applyCrmExportKeyAlignment,
    applyCrmMappingSelection,
    applyCrmOptionsSync,
    buildCrmMappingFieldLookup,
    buildCrmUnmappedCounts,
    getCrmMappingFieldStateKey,
    hydrateCrmMappingDraft,
    mergeCrmAutoMappedDraft,
  } from '../../lib/crm-mapping/draft';
  import { isCrmPropertyCompatible } from '../../lib/crm-mapping/properties';
  import { serializeCrmMappingFields } from '../../lib/crm-mapping/serialization';
  import { CrmAiAutoMapWorkflow } from '../../lib/crm-mapping/ai-workflow.svelte.js';
  import { CrmLiveValidationWorkflow } from '../../lib/crm-mapping/live-validation.svelte.js';
  import CrmMappingSummary from './crm-mapping/CrmMappingSummary.svelte';
  import CrmMappingTable from './crm-mapping/CrmMappingTable.svelte';
  import CrmProviderStatus from './crm-mapping/CrmProviderStatus.svelte';
  import { isLayoutField } from './form-builder/types';

  interface AiAutoMapReviewNotice {
    tone: 'success' | 'warning';
    message: string;
  }

  interface CrmProviderProperties {
    contact?: Array<Record<string, unknown>>;
    company?: Array<Record<string, unknown>>;
  }

  let { 
    open = $bindable(false), 
    form = {}, 
    crmProperties = {}, 
    activeCrmProviders = [],
    loadingProperties = false, 
    fields = [],
    onsave,
    ontestcrm,
    showTestAction = true,
    testingCrm = false,
    testCrmSuccess = false
  } = $props();

  let mappings = $state<Record<string, Record<string, any>>>({});
  let exportKeyOverrides = $state<Record<string, string>>({});
  let optionsOverrides = $state<Record<string, string[]>>({});
  let hasHydratedForOpen = $state(false);
  const aiWorkflow = new CrmAiAutoMapWorkflow();
  const validationWorkflow = new CrmLiveValidationWorkflow();
  const indexedFields = $derived(fields.map((field, index) => ({ field, index })));
  const dataFields = $derived(indexedFields.filter(({ field }) => !isLayoutField(field.field_type)));
  const fieldIdToStateKey = $derived(buildCrmMappingFieldLookup(dataFields));
  let unmappedCounts = $derived.by(() => buildCrmUnmappedCounts(Object.keys(crmProperties), dataFields, mappings));
  let aiLoadingFieldKeys = $derived.by(() => aiWorkflow.loadingFieldKeys);
  const hasActiveAiRun = $derived.by(() => aiWorkflow.hasActiveRun);
  const hasBlockingCrmValidationIssues = $derived.by(() => Object.values(validationWorkflow.issues).some((providerIssues) => Object.values(providerIssues).some((issues) => issues.length > 0)));
  const hasActiveCrmProviders = $derived(activeCrmProviders.length > 0);
  const hasLoadedCrmProperties = $derived(Object.keys(crmProperties).length > 0);
  const hasAvailableCrmProperties = $derived.by(() => Object.values(crmProperties).some((providerProperties) => {
    const properties = providerProperties as CrmProviderProperties;
    return (properties.contact?.length ?? 0) > 0 || (properties.company?.length ?? 0) > 0;
  }));
  const showCrmPropertiesLoader = $derived(open && hasActiveCrmProviders && loadingProperties);
  const showNoActiveCrmConnection = $derived(!showCrmPropertiesLoader && !hasActiveCrmProviders);
  const showCrmPropertiesUnavailable = $derived(!showCrmPropertiesLoader && hasActiveCrmProviders && hasLoadedCrmProperties && !hasAvailableCrmProperties);

  onDestroy(() => {
    aiWorkflow.reset();
    validationWorkflow.abort();
  });

  $effect(() => {
    if (!open) {
      aiWorkflow.reset();
      validationWorkflow.closeSession();
      hasHydratedForOpen = false;
      return;
    }

    if (hasHydratedForOpen) return;

    mappings = hydrateCrmMappingDraft(dataFields);
    exportKeyOverrides = {};
    optionsOverrides = {};
    validationWorkflow.reset();
    hasHydratedForOpen = true;
  });

  function getExportKey(field: any, index: number) {
    return exportKeyOverrides[getCrmMappingFieldStateKey(field, index)] ?? field.metadata?.export_key;
  }

  function getFieldOptions(field: any, index: number) {
    return optionsOverrides[getCrmMappingFieldStateKey(field, index)] ?? field.metadata?.options ?? [];
  }

  function resetCrmValidationState() {
    validationWorkflow.reset();
  }

  function getCrmValidationIssues(provider: string, fieldKey: string) {
    return validationWorkflow.getIssues(provider, fieldKey);
  }

  function getCsrfToken() {
    return (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement | null)?.content || '';
  }

  async function verifyMappingsWithCrm(serializedFields = serializeCrmMappingFields(fields, mappings, exportKeyOverrides, optionsOverrides)) {
    return validationWorkflow.verify({
      formId: form?.id,
      crmProperties,
      serializedFields,
      validationUrl: form?.id ? validate_crm_mapping_form_path(form.id) : null,
      csrfToken: getCsrfToken(),
      isOpen: () => open,
    });
  }

  function handleAutoMap() {
    if (!hasAvailableCrmProperties) return;

    const autoMapped = autoMapFields(fields, crmProperties, (field, prop, provider) => isCrmPropertyCompatible(field, prop, provider));
    const merged = mergeCrmAutoMappedDraft(mappings, exportKeyOverrides, autoMapped, fieldIdToStateKey);
    mappings = merged.mappings;
    exportKeyOverrides = merged.exportKeyOverrides;
    resetCrmValidationState();
  }

  function getAiSuggestion(provider: string, fieldKey: string) {
    return aiWorkflow.getSuggestion(provider, fieldKey);
  }

  function buildAiReviewNotice(remainingCount: number): AiAutoMapReviewNotice {
    if (remainingCount === 0) {
      return {
        tone: 'success',
        message: 'AI auto-map finished. Please verify the suggested mappings before saving, as AI can make mistakes.',
      };
    }

    return {
      tone: 'warning',
      message: `AI auto-map finished for now. ${remainingCount} field${remainingCount > 1 ? 's still need' : ' still needs'} manual mapping. Please verify the suggested mappings before saving, as AI can make mistakes.`,
    };
  }

  function countRemainingFieldsForProvider(provider: string, nextMappings = mappings): number {
    return buildCrmUnmappedCounts([provider], dataFields, nextMappings)[provider] || 0;
  }

  function getAiReviewNotice(provider: string): AiAutoMapReviewNotice | null {
    if (!aiWorkflow.reviewNoticeVisible[provider]) return null;
    return buildAiReviewNotice(countRemainingFieldsForProvider(provider));
  }

  async function handleAiAutoMap(provider: string) {
    if (!form?.id || hasActiveAiRun || !hasAvailableCrmProperties) return;

    resetCrmValidationState();

    await aiWorkflow.run({
      provider,
      formId: form.id,
      isOpen: () => open,
      indexedFields,
      fieldIdToStateKey,
      getDraft: () => ({ mappings, exportKeyOverrides }),
      applyDraftUpdate: (next) => {
        mappings = next.mappings;
        exportKeyOverrides = next.exportKeyOverrides;
      },
      countRemainingFields: countRemainingFieldsForProvider,
      onCompleted: async () => {
        await verifyMappingsWithCrm();
      },
    });
  }

  async function handleSave() {
    if (!hasAvailableCrmProperties) return;

    const serializedFields = serializeCrmMappingFields(fields, mappings, exportKeyOverrides, optionsOverrides);
    const isValid = await verifyMappingsWithCrm(serializedFields);
    if (!isValid) return;

    onsave?.({ fields: serializedFields });
    open = false;
  }

  async function handleTest() {
    if (!hasAvailableCrmProperties) return;

    const serializedFields = serializeCrmMappingFields(fields, mappings, exportKeyOverrides, optionsOverrides);
    const isValid = await verifyMappingsWithCrm(serializedFields);
    if (!isValid) return;

    ontestcrm?.(serializedFields);
  }

  function close() {
    open = false;
  }

  function syncExportKey(fieldKey: string, provider: string) {
    const mapping = mappings[fieldKey]?.[provider];
    exportKeyOverrides = applyCrmExportKeyAlignment(exportKeyOverrides, fieldKey, mapping);
    resetCrmValidationState();
  }

  function syncOptions(fieldKey: string, crmOptions: {label: string, value: string}[]) {
    optionsOverrides = applyCrmOptionsSync(optionsOverrides, fieldKey, crmOptions);
    resetCrmValidationState();
  }

  function updateMapping(fieldKey: string, provider: string, value: string, providerProperties: any, field: any, index: number) {
    mappings = applyCrmMappingSelection(mappings, fieldKey, provider, value, providerProperties, field, index);
    resetCrmValidationState();
  }

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
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="crm-mapping-modal-title"
      class="bg-white rounded-lg shadow-xl w-full max-w-4xl flex flex-col max-h-[90vh]"
    >
      <!-- Header -->
      <div class="px-6 py-4 border-b flex justify-between items-center">
        <h2 id="crm-mapping-modal-title" class="text-xl font-semibold text-gray-800">CRM Field Mapping</h2>
        <div class="flex gap-4 items-center">
          <button 
            type="button" 
            data-testid="auto-map-fields"
            class="text-sm px-3 py-1.5 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 rounded border border-indigo-200 disabled:cursor-not-allowed disabled:opacity-60" 
            onclick={handleAutoMap}
            disabled={hasActiveAiRun || validationWorkflow.validating || !hasAvailableCrmProperties}
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
        {#if showCrmPropertiesLoader}
          <div class="flex flex-col items-center justify-center py-12 gap-3 text-gray-500">
            <Loader2 class="h-8 w-8 animate-spin text-indigo-500" />
            <p class="text-sm font-medium">Fetching CRM properties...</p>
          </div>
        {:else if showNoActiveCrmConnection}
          <div class="p-4 bg-yellow-50 text-yellow-800 rounded-md">
            No active CRM connection found. Please connect a supported CRM account in settings.
          </div>
        {:else if showCrmPropertiesUnavailable}
          <div role="alert" class="p-4 bg-amber-50 text-amber-800 rounded-md">
            Quick KYB could not load your connected CRM properties right now. Please refresh the page and try again.
          </div>
        {:else}
          {#if validationWorkflow.validating}
            <div
              data-testid="crm-live-validation-progress"
              class="mb-4 rounded-md border border-sky-200 bg-sky-50 px-3 py-2 text-sm text-sky-900"
            >
              Quick KYB is verifying the current mappings against your live CRM properties.
            </div>
          {/if}

          {#if validationWorkflow.error}
            <div role="alert" class="mb-4 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
              {validationWorkflow.error}
            </div>
          {/if}

          {#each Object.entries(crmProperties) as [provider, properties]}
            {@const reviewNotice = getAiReviewNotice(provider)}
            {@const providerValidationIssueCount = validationWorkflow.countForProvider(provider)}
            <div class="mb-8" data-provider={provider}>
              <CrmProviderStatus
                {provider}
                formId={form?.id}
                unmappedCount={unmappedCounts[provider] || 0}
                {hasActiveAiRun}
                validatingMappings={validationWorkflow.validating}
                aiLoading={aiWorkflow.loading[provider] || false}
                aiProgress={aiWorkflow.progress[provider]}
                aiError={aiWorkflow.errors[provider] || null}
                {reviewNotice}
                {providerValidationIssueCount}
                onAiAutoMap={() => handleAiAutoMap(provider)}
              />

              {#if summaries[provider]}
                <CrmMappingSummary summary={summaries[provider]} />
              {/if}

              {#if properties && ((properties.contact && properties.contact.length > 0) || (properties.company && properties.company.length > 0))}
                <CrmMappingTable
                  {provider}
                  {properties}
                  {dataFields}
                  {mappings}
                  {aiLoadingFieldKeys}
                  {hasActiveAiRun}
                  validatingMappings={validationWorkflow.validating}
                  {getExportKey}
                  {getFieldOptions}
                  getSuggestion={getAiSuggestion}
                  getValidationIssues={getCrmValidationIssues}
                  onUpdateMapping={updateMapping}
                  onSyncExportKey={syncExportKey}
                  onSyncOptions={syncOptions}
                />
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
        
        {#if showTestAction}
          <button 
            onclick={handleTest}
            class="px-4 py-2 border border-blue-300 text-blue-700 rounded-md hover:bg-blue-50 font-medium disabled:opacity-50"
            disabled={testingCrm || validationWorkflow.validating || hasBlockingCrmValidationIssues || !hasAvailableCrmProperties || hasActiveAiRun}
          >
            {testingCrm ? 'Sending Test...' : 'Send Test Data'}
          </button>
        {/if}

        <button 
          onclick={close}
          class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-100 font-medium"
        >
          Cancel
        </button>
        <button 
          onclick={handleSave}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium disabled:opacity-50"
          disabled={hasActiveAiRun || validationWorkflow.validating || hasBlockingCrmValidationIssues || !hasAvailableCrmProperties}
        >
          Save Mapping
        </button>
      </div>
    </div>
  </div>
{/if}
