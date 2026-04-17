<script lang="ts">
  import type { CrmExportSummary } from '@/lib/crm-utils';

  let {
    summary,
  }: {
    summary: CrmExportSummary;
  } = $props();
</script>

<div class="mb-4 rounded-lg border bg-gray-50 p-4">
  <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Export Preview</p>
  <div class="flex flex-wrap gap-3">
    <div class="flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium {summary.contact.status === 'ready' ? 'bg-green-50 text-green-800 border border-green-200' : 'bg-gray-100 text-gray-500 border border-gray-200'}">
      {#if summary.contact.status === 'ready'}
        <svg class="w-4 h-4 text-green-600 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
        <span>Contact <span class="font-normal">({summary.contact.count} field{summary.contact.count > 1 ? 's' : ''})</span></span>
      {:else}
        <svg class="w-4 h-4 text-gray-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
        <span>No contact</span>
      {/if}
    </div>

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
