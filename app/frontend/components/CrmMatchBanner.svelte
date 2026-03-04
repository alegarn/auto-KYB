<script lang="ts">
  import { onMount } from 'svelte';
  import { router } from '@inertiajs/svelte';
  
  let { clientId, clientEmail } = $props<{ clientId: string, clientEmail?: string }>();
  
  let match = $state<{ external_contact_id: string, name: string, email: string } | null>(null);
  let loading = $state(true);
  let resolved = $state(false);

  onMount(async () => {
    if (!clientEmail) {
      loading = false;
      return;
    }

    try {
      const res = await fetch(`/clients/${clientId}/crm_match_suggestions`);
      const data = await res.json();
      if (data.match) {
        match = data.match;
      }
    } catch (e) {
      console.error(e);
    } finally {
      loading = false;
    }
  });

  function linkContact() {
    if (!match) return;
    router.post(`/clients/${clientId}/link_crm_contact`, { external_contact_id: match.external_contact_id }, {
      preserveScroll: true,
      onSuccess: () => resolved = true
    });
  }

  function createContact() {
    router.post(`/clients/${clientId}/create_crm_contact`, {}, {
      preserveScroll: true,
      onSuccess: () => resolved = true
    });
  }
</script>

{#if !loading && !resolved}
  {#if match}
    <div class="bg-blue-50 border border-blue-200 p-4 rounded-md mb-6 flex justify-between items-center shadow-sm">
      <div>
        <p class="font-medium text-blue-900 border-b border-blue-200/50 pb-1 mb-1">CRM Connection Available</p>
        <p class="text-sm text-blue-800">We found a potential match in your CRM: <strong>{match.name}</strong> ({match.email}).</p>
      </div>
      <div class="flex gap-2">
        <button onclick={linkContact} class="bg-blue-600 text-white text-xs font-semibold px-3 py-1.5 rounded hover:bg-blue-700 transition">Link this contact</button>
        <button onclick={() => match = null} class="text-xs text-blue-700 bg-white border border-blue-200 px-3 py-1.5 rounded hover:bg-blue-100 transition">Dismiss</button>
      </div>
    </div>
  {:else}
    <div class="bg-gray-50 border border-gray-200 p-4 rounded-md mb-6 flex justify-between items-center shadow-sm text-sm">
      <div class="text-gray-700">
        <span class="font-medium block mb-1">CRM Connection</span>
        This client is not linked to your CRM.
      </div>
      <button onclick={createContact} class="bg-white border border-gray-300 text-gray-700 text-xs font-semibold px-3 py-1.5 rounded hover:bg-gray-100 transition shadow-sm">Create contact in CRM</button>
    </div>
  {/if}
{/if}
