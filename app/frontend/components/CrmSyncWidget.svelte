<script lang="ts">
  import { untrack } from 'svelte';
  import { Input } from '/components/ui/input/index.js';
  import { Label } from '/components/ui/label/index.js';

  type CrmSyncStrategy = '' | 'skip' | 'create' | 'link';
  type CrmSearchContact = { external_contact_id: string, name: string, email: string };
  type CrmSyncData = {
    strategy: CrmSyncStrategy;
    external_contact_id: string | null;
    external_company_id: string | null;
    prefillData: { name: string, email: string } | null;
    sync_address_to_contact: boolean;
  };

  let {
    onSyncDataChanged,
    companyName = '',
    allowSkip = true
  } = $props<{ onSyncDataChanged: (data: CrmSyncData) => void, companyName?: string, allowSkip?: boolean }>();

  let strategy = $state<CrmSyncStrategy>(untrack(() => allowSkip ? 'skip' : ''));
  let syncAddressToContact = $state(false);

  // Contact search state
  let searchQuery = $state('');
  let searchResults = $state<CrmSearchContact[]>([]);
  let isSearching = $state(false);
  let selectedContactId = $state<string | null>(null);
  let selectedContactData = $state<{ name: string, email: string } | null>(null);

  // Company match state
  let isSearchingCompany = $state(false);
  let companyMatch = $state<{ hubspot_id: string, company_name: string } | null>(null);
  let linkExistingCompany = $state(true); // default to true if match found

  let searchTimeout: ReturnType<typeof setTimeout>;
  let companySearchTimeout: ReturnType<typeof setTimeout>;

  $effect(() => {
    if (!allowSkip && strategy === 'skip') {
      strategy = '';
    }
  });

  $effect(() => {
    onSyncDataChanged({
      strategy,
      external_contact_id: strategy === 'link' ? selectedContactId : null,
      external_company_id: (strategy === 'create' && linkExistingCompany && companyMatch) ? companyMatch.hubspot_id : null,
      prefillData: strategy === 'link' ? selectedContactData : null,
      sync_address_to_contact: syncAddressToContact
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

  // Watch companyName to check for existence
  $effect(() => {
    if (strategy === 'create' && companyName && companyName.length >= 3) {
      clearTimeout(companySearchTimeout);
      companySearchTimeout = setTimeout(() => {
        checkCompanyExists(companyName);
      }, 1000);
    } else {
      companyMatch = null;
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

  async function checkCompanyExists(name: string) {
    isSearchingCompany = true;
    try {
      const resp = await fetch(`/crm/imports?type=companies&q=${encodeURIComponent(name)}`);
      const results = await resp.json();
      if (results && results.length > 0) {
        // find exact or close match
        const match = results.find((c: any) => c.company_name.toLowerCase() === name.toLowerCase());
        companyMatch = match || results[0];
      } else {
        companyMatch = null;
      }
    } catch (e) {
      console.error(e);
    } finally {
      isSearchingCompany = false;
    }
  }

  function selectContact(contact: CrmSearchContact) {
    selectedContactId = contact.external_contact_id;
    selectedContactData = contact;
    strategy = 'link';
  }
</script>

<div class="border rounded-md p-4 mb-4 bg-muted/20">
  <h3 class="font-medium mb-3">CRM Integration</h3>
  
  <div class="space-y-3">
    {#if allowSkip}
      <div class="flex items-center space-x-2">
        <input type="radio" id="crm-skip" bind:group={strategy} value="skip" />
        <Label for="crm-skip">Do not sync with CRM yet</Label>
      </div>
    {/if}

    <div class="flex items-center space-x-2">
      <input type="radio" id="crm-create" bind:group={strategy} value="create" />
      <Label for="crm-create">Create new contact in CRM</Label>
    </div>

    <div class="flex items-center space-x-2">
      <input type="radio" id="crm-link" bind:group={strategy} value="link" />
      <Label for="crm-link">Link existing CRM contact</Label>
    </div>
  </div>

  {#if strategy === 'create' || (strategy === 'link' && selectedContactId)}
    <div class="mt-4 p-3 border-t bg-background rounded-b-md">
      <label class="flex items-center gap-2 cursor-pointer text-sm font-medium">
        <input type="checkbox" bind:checked={syncAddressToContact} class="rounded border-gray-300 h-4 w-4" />
        <span>Use the company address for the client contact in CRM</span>
      </label>
      <p class="text-xs text-muted-foreground ml-6 mt-1">
        The database in this app will only ever store the company's address.
        Checking this will copy that address to the individual contact record in your CRM.
      </p>
    </div>
  {/if}

  {#if strategy === 'create'}
    {#if isSearchingCompany}
      <div class="mt-4 text-sm text-muted-foreground flex items-center">
        <span class="animate-spin mr-2">⟳</span> Checking CRM for company...
      </div>
    {:else if companyMatch}
      <div class="mt-4 bg-amber-50 border border-amber-200 text-amber-900 rounded-md p-3">
        <div class="font-medium text-sm mb-2">Company "{companyMatch.company_name}" already exists in the CRM.</div>
        <div class="flex items-center space-x-2">
          <input type="checkbox" id="link-existing-company" bind:checked={linkExistingCompany} />
          <Label for="link-existing-company" class="text-sm font-normal">Link contact to this existing company</Label>
        </div>
      </div>
    {/if}
  {/if}

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
