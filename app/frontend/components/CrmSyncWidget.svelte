<script lang="ts">
  import { onMount } from 'svelte';
  import { Input } from '/components/ui/input/index.js';
  import { Label } from '/components/ui/label/index.js';

  let { onSyncDataChanged } = $props<{ onSyncDataChanged: (data: any) => void }>();

  let strategy = $state('skip');
  let searchQuery = $state('');
  let searchResults = $state<{ external_contact_id: string, name: string, email: string }[]>([]);
  let isSearching = $state(false);
  let selectedContactId = $state<string | null>(null);
  let selectedContactData = $state<{ name: string, email: string } | null>(null);

  let searchTimeout: ReturnType<typeof setTimeout>;

  $effect(() => {
    onSyncDataChanged({
      strategy,
      external_contact_id: selectedContactId,
      prefillData: selectedContactData
    });
  });

  $effect(() => {
    if (strategy === 'link' && searchQuery.length >= 3 && !selectedContactId) {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => {
        searchCrm();
      }, 700);
    }
  });

  async function searchCrm() {
    if (!searchQuery) return;
    isSearching = true;
    try {
      const resp = await fetch(`/crm/imports?q=${encodeURIComponent(searchQuery)}`);
      searchResults = await resp.json();
    } catch (e) {
      console.error(e);
    } finally {
      isSearching = false;
    }
  }

  function selectContact(contact: { external_contact_id: string, name: string, email: string }) {
    selectedContactId = contact.external_contact_id;
    selectedContactData = contact;
    strategy = 'link';
  }
</script>

<div class="border rounded-md p-4 mb-4 bg-muted/20">
  <h3 class="font-medium mb-3">CRM Integration</h3>
  
  <div class="space-y-3">
    <div class="flex items-center space-x-2">
      <input type="radio" id="crm-skip" bind:group={strategy} value="skip" />
      <Label for="crm-skip">Do not sync with CRM</Label>
    </div>

    <div class="flex items-center space-x-2">
      <input type="radio" id="crm-create" bind:group={strategy} value="create" />
      <Label for="crm-create">Create new contact in CRM</Label>
    </div>

    <div class="flex items-center space-x-2">
      <input type="radio" id="crm-link" bind:group={strategy} value="link" />
      <Label for="crm-link">Link existing CRM contact</Label>
    </div>
  </div>

  {#if strategy === 'link'}
    <div class="mt-4 border-t pt-4">
      {#if !selectedContactId}
        <div class="flex gap-2">
          <Input 
            bind:value={searchQuery} 
            placeholder="Search by email or name..." 
            onkeydown={(e) => e.key === 'Enter' && searchQuery && (e.preventDefault(), searchCrm())}
          />
          <button type="button" class="bg-primary text-primary-foreground px-4 py-2 rounded-md font-medium text-sm" onclick={searchCrm} disabled={isSearching}>
            {isSearching ? 'Searching...' : 'Search'}
          </button>
        </div>

        {#if searchResults.length > 0}
          <ul class="mt-3 border rounded-md divide-y bg-background">
            {#each searchResults as contact}
              <li>
                <button type="button" class="w-full text-left p-3 hover:bg-muted focus:bg-muted transition-colors flex justify-between items-center" onclick={() => selectContact(contact)}>
                  <div>
                    <div class="font-medium text-sm">{contact.name}</div>
                    <div class="text-xs text-muted-foreground">{contact.email}</div>
                  </div>
                  <span class="text-xs text-blue-600 font-medium bg-blue-50 px-2 py-1 rounded">Select</span>
                </button>
              </li>
            {/each}
          </ul>
        {/if}
        {#if searchResults.length === 0 && !isSearching && searchQuery}
          <div class="mt-2 text-sm text-muted-foreground">No contacts found.</div>
        {/if}
      {:else}
        <div class="bg-blue-50 border border-blue-200 text-blue-900 rounded-md p-3 flex justify-between items-center">
          <div>
            <span class="font-medium block text-sm">Linked Contact</span>
            <span class="text-xs">{selectedContactData?.name} ({selectedContactData?.email})</span>
          </div>
          <button type="button" class="text-xs font-semibold text-blue-700 hover:underline" onclick={() => { selectedContactId = null; selectedContactData = null; }}>
            Change
          </button>
        </div>
      {/if}
    </div>
  {/if}
</div>
