<script lang="ts">
  import { Loader2 } from '@lucide/svelte';

  import type { CrmAiAutoMapProgress } from '@/lib/crm-mapping/ai-workflow.svelte.js';

  interface ReviewNotice {
    tone: 'success' | 'warning';
    message: string;
  }

  let {
    provider,
    formId,
    unmappedCount,
    hasActiveAiRun = false,
    validatingMappings = false,
    aiLoading = false,
    aiProgress = null,
    aiError = null,
    reviewNotice = null,
    providerValidationIssueCount = 0,
    onAiAutoMap,
  }: {
    provider: string;
    formId?: string | number | null;
    unmappedCount: number;
    hasActiveAiRun?: boolean;
    validatingMappings?: boolean;
    aiLoading?: boolean;
    aiProgress?: CrmAiAutoMapProgress | null;
    aiError?: string | null;
    reviewNotice?: ReviewNotice | null;
    providerValidationIssueCount?: number;
    onAiAutoMap?: () => void;
  } = $props();
</script>

<div class="mb-4 flex items-center justify-between gap-3">
  <h3 class="text-lg font-medium capitalize">{provider} Integration</h3>
  {#if formId && unmappedCount > 0}
    <button
      type="button"
      data-testid={`ai-auto-map-${provider}`}
      class="inline-flex items-center gap-2 rounded-md border border-sky-200 bg-sky-50 px-3 py-1.5 text-sm font-medium text-sky-800 hover:bg-sky-100 disabled:cursor-not-allowed disabled:opacity-60"
      onclick={onAiAutoMap}
      disabled={hasActiveAiRun || validatingMappings}
    >
      {#if aiLoading}
        <Loader2 class="h-4 w-4 animate-spin" />
        {#if aiProgress}
          Mapping round {aiProgress.roundNumber}, batch {aiProgress.batchNumber} of {aiProgress.totalBatches}...
        {:else}
          Analyzing remaining fields...
        {/if}
      {:else}
        AI Auto-Map Remaining ({unmappedCount})
      {/if}
    </button>
  {/if}
</div>

{#if providerValidationIssueCount > 0}
  <div
    data-testid={`crm-validation-${provider}`}
    role="alert"
    class="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900"
  >
    Live CRM verification found {providerValidationIssueCount} blocking issue{providerValidationIssueCount > 1 ? 's' : ''}. Fix {providerValidationIssueCount > 1 ? 'them' : 'it'} before saving or sending test data.
  </div>
{/if}

{#if aiError}
  <div role="alert" class="mb-4 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
    {aiError}
  </div>
{/if}

{#if aiLoading && aiProgress}
  <div
    data-testid={`ai-progress-${provider}`}
    class="mb-4 rounded-md border border-sky-200 bg-sky-50 px-3 py-2 text-sm text-sky-900"
  >
    Quick KYB is still mapping the remaining fields. Batch {aiProgress.batchNumber} of {aiProgress.totalBatches} in round {aiProgress.roundNumber}, {aiProgress.mappedCount} mapped in this run, {aiProgress.remainingCount} still remaining.
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
