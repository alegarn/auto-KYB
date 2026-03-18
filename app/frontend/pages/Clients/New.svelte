<script lang="ts">
  import { Form as InertiaForm } from '@inertiajs/svelte';
  import { onMount } from 'svelte';
  import Button from '/components/ui/button/button.svelte';
  import { Label } from '/components/ui/label/index.js';
  import CrmSyncWidget from '@/components/CrmSyncWidget.svelte';
  import CrmSyncNotice from '@/components/CrmSyncNotice.svelte';
  import ClientFormFields from '@/components/ClientFormFields.svelte';
  import { fetchCountriesData } from '/lib/countries';
  import { mapCrmPrefillToForm, type ClientFormData } from '@/lib/crm_domain';
  import { hasError } from '@/lib/utils';

  let { user, errors = {}, forms = [] } = $props();

  let countries = $state([{ name: 'United States', code: 'US', flag: '🇺🇸' }]);
  let countryOptions = $derived((countries || []).map((c: any) => ({ label: c.name, value: c.code, flag: c.flag })));
  let countriesLoading = $state(false);
  let countriesError = $state(null);

  let formData = $state<ClientFormData>({
    name: '',
    email: '',
    phone: '',
    companyName: '',
    companyId: '',
    selectedCountry: '',
    street: '',
    city: '',
    postal: ''
  });

  let crmSyncData = $state({
    strategy: 'skip',
    external_contact_id: null,
    external_company_id: null,
    prefillData: null,
    sync_address_to_contact: false
  });
  let prefilled = $state(false);

  function handleCrmSync(data: any) {
    // Always update the base data including sync_address_to_contact
    crmSyncData = data;

    if (!data.prefillData) {
      return;
    }

    // Prefill logic
    const prefills = mapCrmPrefillToForm(data.prefillData);
    Object.entries(prefills).forEach(([key, value]) => {
      if (value !== undefined) {
        formData[key as keyof ClientFormData] = value;
      }
    });
  }

  async function fetchCountries() {
    countriesLoading = true;
    countriesError = null;
    try {
      const data = await fetchCountriesData();
      countries = data;
    } catch (err: any) {
      console.error('Failed to load countries', err);
      countriesError = err?.message || 'Failed to load countries';
    } finally {
      countriesLoading = false;
    }
  }

  onMount(() => {
    fetchCountries();
  });
</script>

<section class="p-6 max-w-3xl mx-auto">
  <header class="mb-4">
    <h1 class="text-2xl font-semibold">New client</h1>
    <p class="text-sm text-muted-foreground">{user?.email}</p>
  </header>

  {#if Array.isArray(errors) && errors.length}
    <div class="mb-4 text-rose-600">
      <ul>
        {#each errors as err}
          <li>{err}</li>
        {/each}
      </ul>
    </div>
  {/if}

  {#if !Array.isArray(errors) && Object.keys(errors || {}).length}
    <div class="mb-4 text-rose-600">
      <ul>
        {#each Object.entries(errors) as [field, msgs]}
          {#each msgs as msg}
            <li>{field}: {msg}</li>
          {/each}
        {/each}
      </ul>
    </div>
  {/if}

  <InertiaForm method="post" action="/clients">
    <div class="space-y-6 max-w-2xl">
      <!-- Section 1: CRM & Form -->
      <section class="border rounded-lg overflow-hidden shadow-sm bg-muted/5">
        <div class="bg-muted/20 px-4 py-2 border-b">
          <h2 class="text-sm font-semibold uppercase tracking-wider text-muted-foreground">1. Integration & Relationship</h2>
        </div>
        <div class="p-4 space-y-4">
          <CrmSyncWidget onSyncDataChanged={handleCrmSync} companyName={formData.companyName} />
          <input type="hidden" name="crm[strategy]" value={crmSyncData.strategy} />
          {#if crmSyncData.external_contact_id}
            <input type="hidden" name="crm[external_contact_id]" value={crmSyncData.external_contact_id} />
          {/if}
          {#if crmSyncData.external_company_id}
            <input type="hidden" name="crm[external_company_id]" value={crmSyncData.external_company_id} />
          {/if}
          <input type="hidden" name="crm[sync_address_to_contact]" value={crmSyncData.sync_address_to_contact ? 'true' : 'false'} />

          <div>
            <Label for="client-form" class="block text-sm font-medium">Form to link</Label>
            <select
              id="client-form"
              name="client_form[form_id]"
              class={`w-full border rounded px-3 py-2 bg-background ${hasError(errors, 'form_id') ? 'border-rose-600' : ''}`}
              required={forms && forms.length > 0}
              disabled={!forms || forms.length === 0}
            >
              <option value="">Select a form</option>
              {#each forms as form}
                <option value={form.id}>{form.name}</option>
              {/each}
            </select>
            {#if hasError(errors, 'form_id')}
              <div class="text-rose-600 text-sm mt-1">{errors['form_id']?.[0]}</div>
            {/if}
            {#if !forms || forms.length === 0}
              <p class="text-sm text-muted-foreground mt-1">No forms available yet. Create a form first to enable subspace access.</p>
            {/if}
          </div>
        </div>
      </section>

      <ClientFormFields 
        formData={formData} 
        {errors} 
        {countries} 
        countriesLoading={countriesLoading} 
        countriesError={countriesError}
        onFetchCountries={fetchCountries}
      />

      <section class="border rounded-lg overflow-hidden shadow-sm">
        <div class="p-4">
          <CrmSyncNotice 
            strategy={crmSyncData.strategy} 
            companyName={formData.companyName} 
            companyId={formData.companyId} 
          />
        </div>
      </section>
    </div>

    <div class="mt-8 pt-6 border-t flex gap-3 items-center">
      <Button type="submit" class="btn px-8">Create Client Profile</Button>
      <Button href="/clients" class="btn btn-ghost">Cancel</Button>
    </div>
  </InertiaForm>
</section>
