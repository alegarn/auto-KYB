<script lang="ts">
  import { onDestroy } from 'svelte';
  import { Select, SelectContent, SelectItem, SelectTrigger } from "@/components/ui/select/index.js";
  import { ChevronsUpDown, Loader2, Search } from "@lucide/svelte";
  import { cn } from "../../lib/utils";
  import { requestAiAutoMap, type AiSuggestion } from '@/lib/crm/ai-auto-map';
  import { analyzeMappings, autoMapFields, getCrmObjectLabel, getFieldDataType, getProviderFileActions, type CrmExportSummary } from '../../lib/crm-utils';
  import {
    aiSuggestionMatchesCrmMapping,
    applyCrmExportKeyAlignment,
    applyCrmMappingSelection,
    applyCrmOptionsSync,
    buildAiAutoMapRequest,
    buildAiLoadingFieldKeySets,
    buildCrmMappingFieldLookup,
    buildCrmUnmappedCounts,
    DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE,
    filterCrmProperties,
    getAiAutoMapErrorMessage,
    getCrmMappingFieldStateKey,
    getCrmMappingPropertyName,
    getCrmMappingSelectionValue,
    hasCrmOptionsMismatch,
    hydrateCrmMappingDraft,
    isCrmPropertyCompatible,
    mergeAiSuggestionsDraft,
    mergeCrmAutoMappedDraft,
    normalizeAiSuggestions,
    serializeCrmMappingFields,
  } from '../../lib/crm-mapping-modal';
  import { isLayoutField } from './form-builder/types';

  interface AiAutoMapProgress {
    roundNumber: number;
    batchNumber: number;
    totalBatches: number;
    mappedCount: number;
    remainingCount: number;
  }

  interface AiAutoMapReviewNotice {
    tone: 'success' | 'warning';
    message: string;
  }

  let { 
    open = $bindable(false), 
    form = {}, 
    crmProperties = {}, 
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
  let fieldSearch = $state<Record<string, string>>({});
  let aiSuggestions = $state<Record<string, Record<string, AiSuggestion>>>({});
  let aiLoading = $state<Record<string, boolean>>({});
  let aiPendingFieldKeys = $state<Record<string, string[]>>({});
  let aiErrors = $state<Record<string, string | null>>({});
  let aiProgress = $state<Record<string, AiAutoMapProgress | null>>({});
  let aiReviewNoticeVisible = $state<Record<string, boolean>>({});
  let hasHydratedForOpen = $state(false);
  const aiRequestControllers = new Map<string, AbortController>();
  const indexedFields = $derived(fields.map((field, index) => ({ field, index })));
  const dataFields = $derived(indexedFields.filter(({ field }) => !isLayoutField(field.field_type)));
  const fieldIdToStateKey = $derived(buildCrmMappingFieldLookup(dataFields));
  let unmappedCounts = $derived.by(() => buildCrmUnmappedCounts(Object.keys(crmProperties), dataFields, mappings));
  let aiLoadingFieldKeys = $derived.by(() => buildAiLoadingFieldKeySets(aiPendingFieldKeys));
  const hasActiveAiRun = $derived.by(() => Object.values(aiLoading).some(Boolean));

  onDestroy(() => {
    for (const controller of aiRequestControllers.values()) {
      controller.abort();
    }
    aiRequestControllers.clear();
  });

  $effect(() => {
    if (!open) {
      for (const controller of aiRequestControllers.values()) {
        controller.abort();
      }
      aiRequestControllers.clear();
      aiSuggestions = {};
      aiLoading = {};
      aiPendingFieldKeys = {};
      aiErrors = {};
      aiProgress = {};
      aiReviewNoticeVisible = {};
      hasHydratedForOpen = false;
      return;
    }

    if (hasHydratedForOpen) return;

    mappings = hydrateCrmMappingDraft(dataFields);
    exportKeyOverrides = {};
    optionsOverrides = {};
    fieldSearch = {};
    aiSuggestions = {};
    aiLoading = {};
    aiPendingFieldKeys = {};
    aiErrors = {};
    aiProgress = {};
    aiReviewNoticeVisible = {};
    hasHydratedForOpen = true;
  });

  function formatSelectedPropertyLabel(provider: string, prop: any, objectType: string) {
    const label = prop?.label || prop?.name || 'Unknown property';
    const type = prop?.type ? ` (${prop.type})` : '';
    return `${label} [${getCrmObjectLabel(provider, objectType)}]${type}`;
  }

  function getExportKey(field: any, index: number) {
    return exportKeyOverrides[getCrmMappingFieldStateKey(field, index)] ?? field.metadata?.export_key;
  }

  function getFieldOptions(field: any, index: number) {
    return optionsOverrides[getCrmMappingFieldStateKey(field, index)] ?? field.metadata?.options ?? [];
  }

  function handleAutoMap() {
    const autoMapped = autoMapFields(fields, crmProperties, (field, prop, provider) => isCrmPropertyCompatible(field, prop, provider));
    const merged = mergeCrmAutoMappedDraft(mappings, exportKeyOverrides, autoMapped, fieldIdToStateKey);
    mappings = merged.mappings;
    exportKeyOverrides = merged.exportKeyOverrides;
  }

  function getAiSuggestion(provider: string, fieldKey: string): AiSuggestion | undefined {
    return aiSuggestions[provider]?.[fieldKey];
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
    if (!aiReviewNoticeVisible[provider]) return null;
    return buildAiReviewNotice(countRemainingFieldsForProvider(provider));
  }

  async function handleAiAutoMap(provider: string) {
    if (!form?.id || hasActiveAiRun) return;

    const initialRequest = buildAiAutoMapRequest(
      indexedFields,
      mappings,
      provider,
      fieldIdToStateKey,
      { batchSize: DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE },
    );

    if (initialRequest.unmappedFields.length === 0) return;

  const maxRounds = Math.max(1, initialRequest.totalUnmappedCount);

    aiLoading = { ...aiLoading, [provider]: true };
    aiPendingFieldKeys = { ...aiPendingFieldKeys, [provider]: [] };
    aiErrors = { ...aiErrors, [provider]: null };
    aiProgress = { ...aiProgress, [provider]: null };
  aiReviewNoticeVisible = { ...aiReviewNoticeVisible, [provider]: false };
    aiRequestControllers.get(provider)?.abort();

    const controller = new AbortController();
    aiRequestControllers.set(provider, controller);

    try {
      let roundNumber = 0;
      let totalMappedThisRun = 0;
      let encounteredError = false;

      while (roundNumber < maxRounds) {
        if (!open || aiRequestControllers.get(provider) !== controller || controller.signal.aborted) return;

        const roundRequest = buildAiAutoMapRequest(
          indexedFields,
          mappings,
          provider,
          fieldIdToStateKey,
          { batchSize: DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE },
        );

        if (roundRequest.unmappedFields.length === 0) break;

        roundNumber += 1;
        let mappedThisRound = 0;
        const roundFieldIds = roundRequest.allUnmappedFieldIds;
        const totalBatches = Math.ceil(roundFieldIds.length / DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE);

        for (let batchIndex = 0; batchIndex < totalBatches; batchIndex += 1) {
          if (!open || aiRequestControllers.get(provider) !== controller || controller.signal.aborted) return;

          const batchFieldIds = roundFieldIds.slice(
            batchIndex * DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE,
            (batchIndex + 1) * DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE,
          );

          const request = buildAiAutoMapRequest(
            indexedFields,
            mappings,
            provider,
            fieldIdToStateKey,
            { fieldIds: batchFieldIds },
          );

          if (request.unmappedFields.length === 0) continue;

          aiPendingFieldKeys = {
            ...aiPendingFieldKeys,
            [provider]: request.pendingFieldKeys,
          };
          aiProgress = {
            ...aiProgress,
            [provider]: {
              roundNumber,
              batchNumber: batchIndex + 1,
              totalBatches,
              mappedCount: totalMappedThisRun,
              remainingCount: request.totalUnmappedCount,
            },
          };

          const result = await requestAiAutoMap(
            form.id,
            provider,
            request.unmappedFields,
            request.alreadyMapped,
            request.draftFields,
            controller.signal,
          );

          if (!open || aiRequestControllers.get(provider) !== controller || controller.signal.aborted) return;

          const merged = mergeAiSuggestionsDraft(
            mappings,
            exportKeyOverrides,
            result.suggestions,
            provider,
            fieldIdToStateKey,
          );
          const remainingAfterBatch = countRemainingFieldsForProvider(provider, merged.mappings);
          const mappedThisBatch = Math.max(0, request.totalUnmappedCount - remainingAfterBatch);

          mappedThisRound += mappedThisBatch;
          totalMappedThisRun += mappedThisBatch;

          mappings = merged.mappings;
          exportKeyOverrides = merged.exportKeyOverrides;
          aiSuggestions = {
            ...aiSuggestions,
            [provider]: {
              ...(aiSuggestions[provider] || {}),
              ...normalizeAiSuggestions(result.suggestions, fieldIdToStateKey),
            },
          };
          aiProgress = {
            ...aiProgress,
            [provider]: {
              roundNumber,
              batchNumber: batchIndex + 1,
              totalBatches,
              mappedCount: totalMappedThisRun,
              remainingCount: remainingAfterBatch,
            },
          };

          if (result.error) {
            aiErrors = { ...aiErrors, [provider]: getAiAutoMapErrorMessage(result.error) };
            encounteredError = true;
            break;
          }
        }

        if (encounteredError) break;

        const remainingAfterRound = countRemainingFieldsForProvider(provider);
        if (remainingAfterRound === 0 || mappedThisRound === 0) break;
      }

      if (!encounteredError) {
        aiReviewNoticeVisible = { ...aiReviewNoticeVisible, [provider]: true };
      }
    } catch (error: unknown) {
      if (controller.signal.aborted) return;

      const message = error instanceof Error ? error.message : 'ai_auto_map_failed';
      aiErrors = { ...aiErrors, [provider]: getAiAutoMapErrorMessage(message) };
    } finally {
      if (aiRequestControllers.get(provider) === controller) {
        aiRequestControllers.delete(provider);
        aiLoading = { ...aiLoading, [provider]: false };
        aiPendingFieldKeys = { ...aiPendingFieldKeys, [provider]: [] };
        aiProgress = { ...aiProgress, [provider]: null };
      }
    }
  }

  function handleSave() {
    onsave?.({ fields: serializeCrmMappingFields(fields, mappings, exportKeyOverrides, optionsOverrides) });
    open = false;
  }

  function handleTest() {
    ontestcrm?.(serializeCrmMappingFields(fields, mappings, exportKeyOverrides, optionsOverrides));
  }

  function close() {
    open = false;
  }

  function syncExportKey(fieldKey: string, provider: string) {
    const mapping = mappings[fieldKey]?.[provider];
    exportKeyOverrides = applyCrmExportKeyAlignment(exportKeyOverrides, fieldKey, mapping);
  }

  function syncOptions(fieldKey: string, crmOptions: {label: string, value: string}[]) {
    optionsOverrides = applyCrmOptionsSync(optionsOverrides, fieldKey, crmOptions);
  }

  function updateMapping(fieldKey: string, provider: string, value: string, providerProperties: any, field: any, index: number) {
    mappings = applyCrmMappingSelection(mappings, fieldKey, provider, value, providerProperties, field, index);
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
    <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl flex flex-col max-h-[90vh]">
      <!-- Header -->
      <div class="px-6 py-4 border-b flex justify-between items-center">
        <h2 class="text-xl font-semibold text-gray-800">CRM Field Mapping</h2>
        <div class="flex gap-4 items-center">
          <button 
            type="button" 
            data-testid="auto-map-fields"
            class="text-sm px-3 py-1.5 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 rounded border border-indigo-200 disabled:cursor-not-allowed disabled:opacity-60" 
            onclick={handleAutoMap}
            disabled={hasActiveAiRun}
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
            {@const reviewNotice = getAiReviewNotice(provider)}
            <div class="mb-8" data-provider={provider}>
              <div class="mb-4 flex items-center justify-between gap-3">
                <h3 class="text-lg font-medium capitalize">{provider} Integration</h3>
                {#if form?.id && unmappedCounts[provider] > 0}
                  <button
                    type="button"
                    data-testid={`ai-auto-map-${provider}`}
                    class="inline-flex items-center gap-2 rounded-md border border-sky-200 bg-sky-50 px-3 py-1.5 text-sm font-medium text-sky-800 hover:bg-sky-100 disabled:cursor-not-allowed disabled:opacity-60"
                    onclick={() => handleAiAutoMap(provider)}
                    disabled={hasActiveAiRun}
                  >
                    {#if aiLoading[provider]}
                      <Loader2 class="h-4 w-4 animate-spin" />
                      {#if aiProgress[provider]}
                        Mapping round {aiProgress[provider]?.roundNumber}, batch {aiProgress[provider]?.batchNumber} of {aiProgress[provider]?.totalBatches}...
                      {:else}
                        Analyzing remaining fields...
                      {/if}
                    {:else}
                      AI Auto-Map Remaining ({unmappedCounts[provider]})
                    {/if}
                  </button>
                {/if}
              </div>

              {#if aiErrors[provider]}
                <div role="alert" class="mb-4 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
                  {aiErrors[provider]}
                </div>
              {/if}

              {#if aiLoading[provider] && aiProgress[provider]}
                <div
                  data-testid={`ai-progress-${provider}`}
                  class="mb-4 rounded-md border border-sky-200 bg-sky-50 px-3 py-2 text-sm text-sky-900"
                >
                  Quick KYB is still mapping the remaining fields. Batch {aiProgress[provider]?.batchNumber} of {aiProgress[provider]?.totalBatches} in round {aiProgress[provider]?.roundNumber}, {aiProgress[provider]?.mappedCount} mapped in this run, {aiProgress[provider]?.remainingCount} still remaining.
                </div>
              {/if}

              {#if reviewNotice}
                <div
                  data-testid={`ai-review-notice-${provider}`}
                  role="status"
                  class={`mb-4 rounded-md border px-3 py-2 text-sm ${reviewNotice.tone === 'success' ? 'border-emerald-200 bg-emerald-50 text-emerald-900' : 'border-amber-300 bg-amber-50 text-amber-900'}`}
                >
                  {reviewNotice.message}
                </div>
              {/if}
              
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
                        {@const fieldKey = getCrmMappingFieldStateKey(field, index)}
                        {@const mapping = mappings[fieldKey]?.[provider]}
                        {@const currentValue = getCrmMappingSelectionValue(mapping)}
                        {@const rawPropName = getCrmMappingPropertyName(mapping)}
                        {@const suggestion = getAiSuggestion(provider, fieldKey)}
                        {@const showAiBadge = aiSuggestionMatchesCrmMapping(mapping, suggestion)}
                        {@const showCustomSuggestion = !mapping && suggestion?.suggest_custom && !suggestion?.property_name}
                        {@const customPropertyName = mapping?.type === 'custom' ? rawPropName : ''}
                        {@const isAiLoadingField = aiLoadingFieldKeys[provider]?.has(fieldKey)}
                        {@const selectedProp = mapping?.type === 'existing' 
                          ? (properties[mapping.object_type] || []).find((p: any) => p.name === rawPropName) 
                          : null}
                        {@const isCompatible = !selectedProp || isCrmPropertyCompatible(field, selectedProp, provider)}
                        {@const providerFileActions = getProviderFileActions(provider)}
                        {@const selectedFileAction = providerFileActions.find(a => a.value === currentValue)}

                        <tr class="hover:bg-gray-50">
                          <td class="px-4 py-3 font-medium text-gray-900">
                            <div class="flex flex-col">
                              <div class="flex items-center gap-2">
                                <span>{field.label || field.id || 'Unnamed Field'}</span>
                                {#if showAiBadge}
                                  <span
                                    data-testid={`ai-badge-${fieldKey}-${provider}`}
                                    class="inline-flex items-center gap-1 rounded bg-emerald-50 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-700"
                                    title={suggestion?.reason}
                                  >
                                    AI
                                    <span class={suggestion?.confidence === 'high' ? 'text-emerald-500' : 'text-amber-500'}>●</span>
                                  </span>
                                {/if}
                              </div>
                              <div class="flex items-center gap-1.5 mt-0.5">
                                <span class="text-[10px] text-gray-500 uppercase font-semibold">Type: {getFieldDataType(field)}</span>
                                {#if getExportKey(field, index)}
                                  <span class="text-[10px] text-indigo-100 bg-indigo-600 px-1 rounded-sm font-mono tracking-tight" title="Data Export Key: {getExportKey(field, index)}">Key: {getExportKey(field, index)}</span>
                                {/if}
                              </div>
                            </div>
                          </td>
                          <td class="px-4 py-3">
                            <div class="space-y-1">
                              <Select
                                type="single"
                                value={currentValue || undefined}
                                onValueChange={(value) => updateMapping(fieldKey, provider, value, properties, field, index)}
                                onOpenChange={(isOpen: boolean) => { if (!isOpen) fieldSearch[`${fieldKey}-${provider}`] = ''; }}
                                disabled={hasActiveAiRun}
                              >
                                <SelectTrigger
                                  class={cn(
                                    "flex h-9 w-full items-center justify-between rounded-md border border-gray-300 bg-white px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500",
                                    !isCompatible && "border-red-300 ring-1 ring-red-300"
                                  )}
                                  data-testid={`crm-mapping-select-${fieldKey}-${provider}`}
                                >
                                  {#if currentValue === "__custom_contact__" || currentValue === "__custom_company__"}
                                    + Create as Custom {getCrmObjectLabel(provider, mapping?.object_type || (currentValue === '__custom_company__' ? 'company' : 'contact'))} Property
                                  {:else if selectedFileAction}
                                    {selectedFileAction.label}
                                  {:else}
                                    {selectedProp ? formatSelectedPropertyLabel(provider, selectedProp, mapping.object_type) : "-- Do not map --"}
                                  {/if}
                                  <ChevronsUpDown class="h-4 w-4 opacity-50" />
                                </SelectTrigger>
                                <SelectContent 
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
                                        if (e.key === ' ') e.stopPropagation();
                                      }}
                                    />
                                  </div>
                                  <div class="max-h-60 overflow-y-auto">
                                    <SelectItem
                                      value=""
                                      class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                      data-slot="select-item"
                                    >
                                      -- Do not map --
                                    </SelectItem>
                                    <SelectItem
                                      value="__custom_contact__"
                                      class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm font-semibold text-blue-600 outline-none focus:bg-blue-50 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                      data-slot="select-item"
                                    >
                                      + Create as Custom {getCrmObjectLabel(provider, 'contact')} Property
                                    </SelectItem>
                                    <SelectItem
                                      value="__custom_company__"
                                      class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm font-semibold text-blue-600 outline-none focus:bg-blue-50 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                      data-slot="select-item"
                                    >
                                      + Create as Custom {getCrmObjectLabel(provider, 'company')} Property
                                    </SelectItem>
                                    
                                    {#if getFieldDataType(field) === 'file' && providerFileActions.length > 0}
                                      <div class="px-2 py-1.5 text-xs font-semibold text-gray-400">File Actions</div>
                                      {#each providerFileActions as fileAction}
                                        <SelectItem
                                          value={fileAction.value}
                                          class="relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
                                          data-slot="select-item"
                                        >
                                          {fileAction.label}
                                        </SelectItem>
                                      {/each}
                                    {/if}

                                    <div class="px-2 py-1.5 text-xs font-semibold text-gray-400">Existing {getCrmObjectLabel(provider, 'contact')} Properties</div>
                                    {#each filterCrmProperties(properties.contact || [], fieldSearch[`${fieldKey}-${provider}`], field, provider) as prop}
                                      <SelectItem
                                        value={`contact:${prop.name}`}
                                        disabled={prop.read_only}
                                        class={cn(
                                          "relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
                                          !isCrmPropertyCompatible(field, prop, provider) && "text-gray-400"
                                        )}
                                        data-slot="select-item"
                                      >
                                        <span class="flex-1 truncate">{prop.label || prop.name} [{getCrmObjectLabel(provider, 'contact')}] {prop.read_only ? '(Read Only)' : ''}</span>
                                        <span class="ml-2 text-[10px] text-gray-400 uppercase tracking-tighter">{prop.type}</span>
                                      </SelectItem>
                                    {/each}

                                    <div class="px-2 py-1.5 text-xs font-semibold text-gray-400">Existing {getCrmObjectLabel(provider, 'company')} Properties</div>
                                    {#each filterCrmProperties(properties.company || [], fieldSearch[`${fieldKey}-${provider}`], field, provider) as prop}
                                      <SelectItem
                                        value={`company:${prop.name}`}
                                        disabled={prop.read_only}
                                        class={cn(
                                          "relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
                                          !isCrmPropertyCompatible(field, prop, provider) && "text-gray-400"
                                        )}
                                        data-slot="select-item"
                                      >
                                        <span class="flex-1 truncate">{prop.label || prop.name} [{getCrmObjectLabel(provider, 'company')}] {prop.read_only ? '(Read Only)' : ''}</span>
                                        <span class="ml-2 text-[10px] text-gray-400 uppercase tracking-tighter">{prop.type}</span>
                                      </SelectItem>
                                    {/each}
                                  </div>
                                </SelectContent>
                              </Select>

                              {#if isAiLoadingField}
                                <div
                                  data-testid={`ai-loading-${fieldKey}-${provider}`}
                                  class="h-8 rounded-md border border-sky-100 bg-sky-50 animate-pulse"
                                ></div>
                              {/if}

                              {#if customPropertyName}
                                <p
                                  data-testid={`custom-property-${fieldKey}-${provider}`}
                                  class="text-xs text-amber-600 font-medium"
                                >
                                  Custom property: <span class="font-mono">{customPropertyName}</span>
                                </p>
                              {/if}

                              {#if showCustomSuggestion}
                                <p
                                  data-testid={`ai-custom-suggestion-${fieldKey}-${provider}`}
                                  class="text-xs text-amber-600 font-medium"
                                  title={suggestion?.reason}
                                >
                                  Create as: <span class="font-mono">{suggestion?.suggested_custom_name}</span>
                                </p>
                              {/if}
                              
                              {#if !isCompatible}
                                <p data-testid={`type-mismatch-${field.id}-${provider}`} class="text-[10px] text-red-600 font-medium">
                                  Type mismatch: {getFieldDataType(field)} vs {selectedProp.type}. This might lead to data issues.
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
                                    class="text-[9px] bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded border border-amber-200 hover:bg-amber-100 transition-colors disabled:cursor-not-allowed disabled:opacity-60"
                                    title="Update Data Export Key to match CRM property name"
                                    disabled={hasActiveAiRun}
                                  >
                                    Align Key
                                  </button>
                                </div>
                              {/if}

                              {#if selectedProp && selectedProp.type === 'enumeration' && selectedProp.options?.length > 0}
                                {@const formOpts = getFieldOptions(field, index)}
                                {#if hasCrmOptionsMismatch(formOpts, selectedProp.options)}
                                  <div class="flex items-center justify-between mt-1">
                                    <p class="text-[10px] text-amber-600 font-medium leading-tight max-w-[80%]">
                                      Options mismatch: Form options don't match CRM allowed values. Submissions may fail.
                                    </p>
                                    <button 
                                      type="button"
                                      onclick={() => syncOptions(fieldKey, selectedProp.options)}
                                      class="text-[9px] bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded border border-amber-200 hover:bg-amber-100 transition-colors shrink-0 disabled:cursor-not-allowed disabled:opacity-60"
                                      title="Overwrite form options with CRM options"
                                      disabled={hasActiveAiRun}
                                    >
                                      Sync Options
                                    </button>
                                  </div>
                                {/if}
                              {/if}
                            </div>
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
        
        {#if showTestAction}
          <button 
            onclick={handleTest}
            class="px-4 py-2 border border-blue-300 text-blue-700 rounded-md hover:bg-blue-50 font-medium disabled:opacity-50"
            disabled={testingCrm || Object.keys(crmProperties).length === 0 || hasActiveAiRun}
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
          disabled={hasActiveAiRun || Object.keys(crmProperties).length === 0}
        >
          Save Mapping
        </button>
      </div>
    </div>
  </div>
{/if}
