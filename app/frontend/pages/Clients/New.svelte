<script lang="ts">
  import { Form as InertiaForm } from '@inertiajs/svelte';
  import { onMount } from 'svelte';
  import Button from '/components/ui/button/button.svelte';
  import Input from '/components/ui/input/input.svelte';
  import { Label } from '/components/ui/label/index.js';
  import CrmSyncWidget from '@/components/CrmSyncWidget.svelte';
  import CrmSyncNotice from '@/components/CrmSyncNotice.svelte';
  import { fetchCountriesData } from '/lib/countries';
  import { mapCrmPrefillToForm, type ClientFormData } from '@/lib/crm_domain';

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

  const hasError = (field: string) => {
    if (!errors) return false;
    if (Array.isArray(errors)) return false;
    return (errors[field] && errors[field].length) || false;
  };
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
              class={`w-full border rounded px-3 py-2 bg-background ${hasError('form_id') ? 'border-rose-600' : ''}`}
              required={forms && forms.length > 0}
              disabled={!forms || forms.length === 0}
            >
              <option value="">Select a form</option>
              {#each forms as form}
                <option value={form.id}>{form.name}</option>
              {/each}
            </select>
            {#if hasError('form_id')}
              <div class="text-rose-600 text-sm mt-1">{errors['form_id']?.[0]}</div>
            {/if}
            {#if !forms || forms.length === 0}
              <p class="text-sm text-muted-foreground mt-1">No forms available yet. Create a form first to enable subspace access.</p>
            {/if}
          </div>
        </div>
      </section>

      <!-- Section 2: Individual Client Info -->
      <section class="border rounded-lg overflow-hidden shadow-sm">
        <div class="bg-muted/10 px-4 py-2 border-b">
          <h2 class="text-sm font-semibold uppercase tracking-wider text-muted-foreground">2. Client Personal Details</h2>
        </div>
        <div class="p-4 space-y-4">
          <div>
            <Label for="client-name" class="block text-sm font-medium">Full Name (Contact Person) <span class="text-rose-600">*</span></Label>
            <Input id="client-name" name="client[name]" required bind:value={formData.name} class={`w-full ${hasError('name') ? 'border-rose-600' : ''}`} />
            {#if hasError('name')}
              <div class="text-rose-600 text-sm mt-1">{errors['name']?.[0]}</div>
            {/if}
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label for="client-email" class="block text-sm font-medium">Personal/Work Email</Label>
              <Input id="client-email" name="client[email]" type="email" bind:value={formData.email} class={`w-full ${hasError('email') ? 'border-rose-600' : ''}`} />
              {#if hasError('email')}
                <div class="text-rose-600 text-sm mt-1">{errors['email']?.[0]}</div>
              {/if}
            </div>

            <div>
              <Label for="client-phone" class="block text-sm font-medium">Phone Number</Label>
              <Input id="client-phone" name="client[phone]" bind:value={formData.phone} class={`w-full ${hasError('phone') ? 'border-rose-600' : ''}`} />
              {#if hasError('phone')}
                <div class="text-rose-600 text-sm mt-1">{errors['phone']?.[0]}</div>
              {/if}
            </div>
          </div>
        </div>
      </section>

      <!-- Section 3: Company Core Info -->
      <section class="border rounded-lg overflow-hidden shadow-sm bg-primary/5 border-primary/20">
        <div class="bg-primary/10 px-4 py-2 border-b border-primary/20 flex justify-between items-center">
          <h2 class="text-sm font-semibold uppercase tracking-wider text-primary/80">3. Company Information</h2>
          <span class="text-[10px] bg-primary/30 text-primary px-2 py-0.5 rounded-full font-bold">BUSINESS DOCS</span>
        </div>
        
        <div class="p-4 space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label for="client-company" class="block text-sm font-medium">Registered Company Name <span class="text-rose-600">*</span></Label>
              <Input id="client-company" name="client[company_name]" required bind:value={formData.companyName} class={`w-full bg-background ${hasError('company_name') ? 'border-rose-600' : ''}`} />
              {#if hasError('company_name')}
                <div class="text-rose-600 text-sm mt-1">{errors['company_name']?.[0]}</div>
              {/if}
            </div>

            <div>
              <Label for="client-company-id" class="block text-sm font-medium">Company Registration ID <span class="text-rose-600">*</span></Label>
              <Input id="client-company-id" name="client[company_id]" required bind:value={formData.companyId} class={`w-full bg-background ${hasError('company_id') ? 'border-rose-600' : ''}`} />
              {#if hasError('company_id')}
                <div class="text-rose-600 text-sm mt-1">{errors['company_id']?.[0]}</div>
              {/if}
            </div>
          </div>

          <div>
            <Label for="client-country" class="block text-sm font-medium">Company's Country of Incorporation</Label>
            {#if countriesLoading}
              <select id="client-country" name="client[country]" disabled class="w-full border rounded px-3 py-2 bg-muted/10">
                <option>Loading countries...</option>
              </select>
            {:else}
              <select id="client-country" name="client[country]" bind:value={formData.selectedCountry} class={`w-full border rounded px-3 py-2 bg-background ${hasError('country') ? 'border-rose-600' : ''}`}>
                <option value="">Select a country</option>
                {#each countryOptions as opt}
                  <option value={opt?.value}>{opt?.flag} {opt?.label}</option>
                {/each}
              </select>
            {/if}
            {#if countriesError}
              <div class="text-rose-600 text-sm mt-1">Error loading countries: {countriesError} <button class="ml-2 underline" onclick={fetchCountries}>Retry</button></div>
            {/if}
            {#if hasError('country')}
              <div class="text-rose-600 text-sm mt-1">{errors['country']?.[0]}</div>
            {/if}
          </div>

          <fieldset class="border p-4 rounded-md bg-background/50">
            <legend class="px-2 text-sm font-medium text-muted-foreground">Business Address</legend>
            <div class="grid grid-cols-1 gap-4 md:grid-cols-2 mt-2">
              <div class="md:col-span-2">
                <Label for="client-street" class="block text-sm">Street</Label>
                <Input id="client-street" name="client[address][street]" bind:value={formData.street} placeholder="e.g. 123 Business Road" class="w-full" />
              </div>
              <div>
                <Label for="client-city" class="block text-sm">City</Label>
                <Input id="client-city" name="client[address][city]" bind:value={formData.city} placeholder="City" />
              </div>
              <div>
                <Label for="client-postal" class="block text-sm">Postal Code</Label>
                <Input id="client-postal" name="client[address][postal_code]" bind:value={formData.postal} placeholder="Code" />
              </div>
            </div>
          </fieldset>

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
