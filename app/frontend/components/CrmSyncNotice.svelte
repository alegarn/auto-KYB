<script lang="ts">
  import { isCompanyInfoCompleted } from '@/lib/crm_domain';

  interface Props {
    strategy: string;
    companyName: string;
    companyId: string;
  }

  let { strategy, companyName, companyId }: Props = $props();

  let showNotice = $derived(
    strategy === 'create' &&
    isCompanyInfoCompleted(companyName, companyId)
  );
</script>

{#if showNotice}
  <div class="bg-blue-50 border border-blue-200 rounded-md p-3 flex items-start gap-3 mt-2">
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-blue-600 mt-0.5"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
    <div>
      <p class="text-sm font-medium text-blue-900 leading-none">New CRM Company Record</p>
      <p class="text-xs text-blue-700 mt-1">This will create a new company record in your CRM with the information provided above.</p>
    </div>
  </div>
{/if}
