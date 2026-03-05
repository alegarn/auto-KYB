<script lang="ts">
  import { Form as InertiaForm } from '@inertiajs/svelte';
  import { onMount } from 'svelte';
  import Button from '/components/ui/button/button.svelte';
  import Input from '/components/ui/input/input.svelte';
  import { Label } from '/components/ui/label/index.js';
  import CrmSyncWidget from '@/components/CrmSyncWidget.svelte';
  import { fetchCountriesData } from '/lib/countries';

  let { user, errors = {}, forms = [] } = $props();

  let countries = $state([{ name: 'United States', code: 'US', flag: '🇺🇸' }]);
  let countryOptions = $derived((countries || []).map((c: any) => ({ label: c.name, value: c.code, flag: c.flag })));
  let selectedCountry = $state('');
  let countriesLoading = $state(false);
  let countriesError = $state(null);

  let crmSyncData = $state({ strategy: 'skip', external_contact_id: null, prefillData: null });
  let prefilled = $state(false);

  function handleCrmSync(data: any) {
    if (!data.prefillData) {
      crmSyncData = { ...data, strategy: data.strategy };
      return;
    }

    // Always update the base data
    crmSyncData = data;

    // Prefill logic
    const nameInput = document.querySelector<HTMLInputElement>('input[name="client[name]"]');
    if (nameInput && data.prefillData.name) nameInput.value = data.prefillData.name;
    
    const emailInput = document.querySelector<HTMLInputElement>('input[name="client[email]"]');
    if (emailInput && data.prefillData.email) emailInput.value = data.prefillData.email;
    
    const companyInput = document.querySelector<HTMLInputElement>('input[name="client[company_name]"]');
    if (companyInput && data.prefillData.company_name) companyInput.value = data.prefillData.company_name;

    const phoneInput = document.querySelector<HTMLInputElement>('input[name="client[phone]"]');
    if (phoneInput && data.prefillData.phone) phoneInput.value = data.prefillData.phone;

    if (data.prefillData.country) {
      selectedCountry = data.prefillData.country;
    }

    if (data.prefillData.address) {
      const streetInput = document.querySelector<HTMLInputElement>('input[name="client[address][street]"]');
      if (streetInput && data.prefillData.address.street) streetInput.value = data.prefillData.address.street;

      const cityInput = document.querySelector<HTMLInputElement>('input[name="client[address][city]"]');
      if (cityInput && data.prefillData.address.city) cityInput.value = data.prefillData.address.city;

      const postalInput = document.querySelector<HTMLInputElement>('input[name="client[address][postal_code]"]');
      if (postalInput && data.prefillData.address.postal_code) postalInput.value = data.prefillData.address.postal_code;
    }
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
    <div class="space-y-4 max-w-2xl">
      <CrmSyncWidget onSyncDataChanged={handleCrmSync} />
      <input type="hidden" name="crm[strategy]" value={crmSyncData.strategy} />
      {#if crmSyncData.external_contact_id}
        <input type="hidden" name="crm[external_contact_id]" value={crmSyncData.external_contact_id} />
      {/if}

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

      <div>
        <Label for="client-name" class="block text-sm font-medium">Name</Label>
        <Input id="client-name" name="client[name]" class={`w-full ${hasError('name') ? 'border-rose-600' : ''}`} />
        {#if hasError('name')}
          <div class="text-rose-600 text-sm mt-1">{errors['name']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-company" class="block text-sm font-medium">Company name</Label>
        <Input id="client-company" name="client[company_name]" class={`w-full ${hasError('company_name') ? 'border-rose-600' : ''}`} />
        {#if hasError('company_name')}
          <div class="text-rose-600 text-sm mt-1">{errors['company_name']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-company-id" class="block text-sm font-medium">Company ID</Label>
        <Input id="client-company-id" name="client[company_id]" class={`w-full ${hasError('company_id') ? 'border-rose-600' : ''}`} />
        {#if hasError('company_id')}
          <div class="text-rose-600 text-sm mt-1">{errors['company_id']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-email" class="block text-sm font-medium">Email</Label>
        <Input id="client-email" name="client[email]" type="email" class={`w-full ${hasError('email') ? 'border-rose-600' : ''}`} />
        {#if hasError('email')}
          <div class="text-rose-600 text-sm mt-1">{errors['email']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-phone" class="block text-sm font-medium">Phone</Label>
        <Input id="client-phone" name="client[phone]" class={`w-full ${hasError('phone') ? 'border-rose-600' : ''}`} />
        {#if hasError('phone')}
          <div class="text-rose-600 text-sm mt-1">{errors['phone']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-country" class="block text-sm font-medium">Company's country</Label>
        {#if countriesLoading}
          <select id="client-country" name="client[country]" disabled class="w-full border rounded px-3 py-2 bg-muted/10">
            <option>Loading countries...</option>
          </select>
        {:else}
          <select id="client-country" name="client[country]" bind:value={selectedCountry} class={`w-full border rounded px-3 py-2 bg-background ${hasError('country') ? 'border-rose-600' : ''}`}>
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

      <fieldset class="mt-4 border p-3 rounded">
        <legend class="text-sm font-medium">Company's Address (optional)</legend>
        <div class="grid grid-cols-1 gap-3 md:grid-cols-2 mt-2">
          <div>
            <Label for="client-street" class="block text-sm">Street</Label>
            <Input id="client-street" name="client[address][street]" />
          </div>
          <div>
            <Label for="client-city" class="block text-sm">City</Label>
            <Input id="client-city" name="client[address][city]" />
          </div>
          <div>
            <Label for="client-postal" class="block text-sm">Postal code</Label>
            <Input id="client-postal" name="client[address][postal_code]" />
          </div>
        </div>
      </fieldset>
    </div>

    <div class="mt-6 flex gap-2 items-center">
      <Button type="submit" class="btn">Create client</Button>
      <Button href="/clients" class="btn btn-ghost">Cancel</Button>
    </div>
  </InertiaForm>
</section>
