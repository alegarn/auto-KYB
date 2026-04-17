<script lang="ts">
  import { onDestroy } from 'svelte';
  import { ChevronLeft, ChevronRight, ChevronsUpDown, Search } from '@lucide/svelte';

  import { Select, SelectContent, SelectItem, SelectTrigger } from '@/components/ui/select/index.js';
  import { aiSuggestionMatchesCrmMapping } from '@/lib/crm-mapping/ai';
  import {
    getCrmMappingFieldStateKey,
    getCrmMappingPropertyName,
    getCrmMappingSelectionValue,
  } from '@/lib/crm-mapping/draft';
  import {
    filterCrmProperties,
    hasCrmOptionsMismatch,
    isCrmPropertyCompatible,
  } from '@/lib/crm-mapping/properties';
  import { MappingTableScrollController } from '@/lib/crm-mapping/table-scroll.svelte.js';
  import { getCrmObjectLabel, getFieldDataType, getProviderFileActions } from '@/lib/crm-utils';

  import { cn } from '../../../lib/utils';

  let {
    provider,
    properties,
    dataFields = [],
    mappings = {},
    aiLoadingFieldKeys = {},
    hasActiveAiRun = false,
    validatingMappings = false,
    getExportKey,
    getFieldOptions,
    getSuggestion,
    getValidationIssues,
    onUpdateMapping,
    onSyncExportKey,
    onSyncOptions,
  }: {
    provider: string;
    properties: Record<string, any[]>;
    dataFields: Array<{ field: any; index: number }>;
    mappings: Record<string, Record<string, any>>;
    aiLoadingFieldKeys?: Record<string, Set<string>>;
    hasActiveAiRun?: boolean;
    validatingMappings?: boolean;
    getExportKey: (field: any, index: number) => string | undefined;
    getFieldOptions: (field: any, index: number) => string[];
    getSuggestion: (provider: string, fieldKey: string) => any;
    getValidationIssues: (provider: string, fieldKey: string) => Array<{ code: string; message: string }>;
    onUpdateMapping: (fieldKey: string, provider: string, value: string, providerProperties: any, field: any, index: number) => void;
    onSyncExportKey: (fieldKey: string, provider: string) => void;
    onSyncOptions: (fieldKey: string, crmOptions: Array<{ label: string; value: string }>) => void;
  } = $props();

  const scroll = new MappingTableScrollController();
  let fieldSearch = $state<Record<string, string>>({});
  const tableHelpId = $derived(`crm-mapping-table-help-${provider}`);
  const providerFileActions = $derived(getProviderFileActions(provider));

  onDestroy(() => {
    scroll.destroy();
  });

  function formatSelectedPropertyLabel(prop: any, objectType: string) {
    const label = prop?.label || prop?.name || 'Unknown property';
    const type = prop?.type ? ` (${prop.type})` : '';
    return `${label} [${getCrmObjectLabel(provider, objectType)}]${type}`;
  }
</script>

<p id={tableHelpId} class="sr-only">
  Focus this area and use the left and right arrow keys to scroll horizontally through the CRM field mapping table. Hover the small controls on the left or right edge to move the table in that direction.
</p>
<div
  class="relative"
  role="group"
  aria-label={`${provider} CRM mapping hover controls`}
  data-testid={`crm-mapping-scroll-shell-${provider}`}
  onpointerenter={scroll.handleAreaEnter}
  onpointerleave={scroll.handleAreaLeave}
>
  <button
    type="button"
    tabindex="-1"
    data-testid={`crm-mapping-scroll-cue-${provider}-left`}
    aria-label={`Scroll ${provider} mapping table left`}
    onmousedown={(event) => event.preventDefault()}
    onpointerenter={() => scroll.handleCueEnter('left')}
    onpointerleave={scroll.handleCueLeave}
    class={cn(
      'pointer-events-none absolute inset-y-4 left-2 z-10 flex w-5 flex-col items-center justify-center rounded-full border border-white/50 bg-white/20 text-gray-500 opacity-0 shadow-sm backdrop-blur-[1px] transition-all duration-150',
      scroll.hoveredArea ? 'pointer-events-auto opacity-100' : '',
      scroll.isCueHovered('left') ? 'border-slate-300/70 bg-white/45 text-gray-800 shadow-md' : 'border-white/40',
    )}
  >
    <ChevronLeft class="h-3 w-3" />
    <span class="mt-1 h-5 w-px bg-current opacity-70"></span>
  </button>

  <button
    type="button"
    tabindex="-1"
    data-testid={`crm-mapping-scroll-cue-${provider}-right`}
    aria-label={`Scroll ${provider} mapping table right`}
    onmousedown={(event) => event.preventDefault()}
    onpointerenter={() => scroll.handleCueEnter('right')}
    onpointerleave={scroll.handleCueLeave}
    class={cn(
      'pointer-events-none absolute inset-y-4 right-2 z-10 flex w-5 flex-col items-center justify-center rounded-full border border-white/50 bg-white/20 text-gray-500 opacity-0 shadow-sm backdrop-blur-[1px] transition-all duration-150',
      scroll.hoveredArea ? 'pointer-events-auto opacity-100' : '',
      scroll.isCueHovered('right') ? 'border-slate-300/70 bg-white/45 text-gray-800 shadow-md' : 'border-white/40',
    )}
  >
    <ChevronRight class="h-3 w-3" />
    <span class="mt-1 h-5 w-px bg-current opacity-70"></span>
  </button>

  <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div
    data-testid="crm-mapping-table-scroll"
    data-scroll-provider={provider}
    role="region"
    aria-label="CRM field mapping table"
    aria-describedby={tableHelpId}
    tabindex="0"
    use:scroll.register
    onkeydown={scroll.handleKeydown}
    class="overflow-x-auto rounded-lg border px-10 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-white"
  >
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
          {@const suggestion = getSuggestion(provider, fieldKey)}
          {@const showAiBadge = aiSuggestionMatchesCrmMapping(mapping, suggestion)}
          {@const showCustomSuggestion = !mapping && suggestion?.suggest_custom && !suggestion?.property_name}
          {@const customPropertyName = mapping?.type === 'custom' ? rawPropName : ''}
          {@const isAiLoadingField = aiLoadingFieldKeys[provider]?.has(fieldKey)}
          {@const selectedProp = mapping?.type === 'existing'
            ? (properties[mapping.object_type] || []).find((property: any) => property.name === rawPropName)
            : null}
          {@const isCompatible = !selectedProp || isCrmPropertyCompatible(field, selectedProp, provider)}
          {@const selectedFileAction = providerFileActions.find((action) => action.value === currentValue)}
          {@const validationIssues = getValidationIssues(provider, fieldKey)}
          {@const validationIssueId = `crm-validation-feedback-${provider}-${fieldKey}`}

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
                  onValueChange={(value) => onUpdateMapping(fieldKey, provider, value, properties, field, index)}
                  onOpenChange={(isOpen: boolean) => { if (!isOpen) fieldSearch[fieldKey] = ''; }}
                  disabled={hasActiveAiRun || validatingMappings}
                >
                  <SelectTrigger
                    class={cn(
                      'flex h-9 w-full items-center justify-between rounded-md border border-gray-300 bg-white px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500',
                      !isCompatible && 'border-red-300 ring-1 ring-red-300'
                    )}
                    aria-invalid={validationIssues.length > 0}
                    aria-describedby={validationIssues.length > 0 ? validationIssueId : undefined}
                    data-testid={`crm-mapping-select-${fieldKey}-${provider}`}
                  >
                    {#if currentValue === '__custom_contact__' || currentValue === '__custom_company__'}
                      + Create as Custom {getCrmObjectLabel(provider, mapping?.object_type || (currentValue === '__custom_company__' ? 'company' : 'contact'))} Property
                    {:else if selectedFileAction}
                      {selectedFileAction.label}
                    {:else}
                      {selectedProp ? formatSelectedPropertyLabel(selectedProp, mapping.object_type) : '-- Do not map --'}
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
                        value={fieldSearch[fieldKey] || ''}
                        oninput={(event) => fieldSearch[fieldKey] = event.currentTarget.value}
                        onkeydown={(event) => {
                          if (event.key === ' ') event.stopPropagation();
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
                      {#each filterCrmProperties(properties.contact || [], fieldSearch[fieldKey] || '', field, provider) as prop}
                        <SelectItem
                          value={`contact:${prop.name}`}
                          disabled={prop.read_only}
                          class={cn(
                            'relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50',
                            !isCrmPropertyCompatible(field, prop, provider) && 'text-gray-400'
                          )}
                          data-slot="select-item"
                        >
                          <span class="flex-1 truncate">{prop.label || prop.name} [{getCrmObjectLabel(provider, 'contact')}] {prop.read_only ? '(Read Only)' : ''}</span>
                          <span class="ml-2 text-[10px] text-gray-400 uppercase tracking-tighter">{prop.type}</span>
                        </SelectItem>
                      {/each}

                      <div class="px-2 py-1.5 text-xs font-semibold text-gray-400">Existing {getCrmObjectLabel(provider, 'company')} Properties</div>
                      {#each filterCrmProperties(properties.company || [], fieldSearch[fieldKey] || '', field, provider) as prop}
                        <SelectItem
                          value={`company:${prop.name}`}
                          disabled={prop.read_only}
                          class={cn(
                            'relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-gray-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50',
                            !isCrmPropertyCompatible(field, prop, provider) && 'text-gray-400'
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

                {#if validationIssues.length > 0}
                  <div id={validationIssueId} role="alert" class="space-y-1">
                    {#each validationIssues as issue}
                      <p
                        data-testid={`crm-validation-issue-${fieldKey}-${provider}-${issue.code}`}
                        class="text-[10px] text-red-600 font-medium"
                      >
                        {issue.message}
                      </p>
                    {/each}
                  </div>
                {/if}

                {#if !isCompatible}
                  <p data-testid={`type-mismatch-${field.id}-${provider}`} class="text-[10px] text-red-600 font-medium">
                    Type mismatch: {getFieldDataType(field)} vs {selectedProp.type}. This might lead to data issues.
                  </p>
                {/if}

                {#if selectedProp && getExportKey(field, index) !== selectedProp.name}
                  <div class="flex items-center justify-between">
                    <p class="text-[10px] text-amber-600 font-medium">
                      Key mismatch with local export key ({getExportKey(field, index) || 'label'}) != {selectedProp.name}
                    </p>
                    <button
                      type="button"
                      onclick={() => onSyncExportKey(fieldKey, provider)}
                      class="text-[9px] bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded border border-amber-200 hover:bg-amber-100 transition-colors disabled:cursor-not-allowed disabled:opacity-60"
                      title="Update Data Export Key to match CRM property name"
                      disabled={hasActiveAiRun || validatingMappings}
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
                        onclick={() => onSyncOptions(fieldKey, selectedProp.options)}
                        class="text-[9px] bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded border border-amber-200 hover:bg-amber-100 transition-colors shrink-0 disabled:cursor-not-allowed disabled:opacity-60"
                        title="Overwrite form options with CRM options"
                        disabled={hasActiveAiRun || validatingMappings}
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
</div>