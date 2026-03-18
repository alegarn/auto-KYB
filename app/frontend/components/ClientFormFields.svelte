<script lang="ts">
  import Input from '/components/ui/input/input.svelte';
  import { Label } from '/components/ui/label/index.js';
  import { hasError } from '@/lib/utils';
  import type { ClientFormData } from '@/lib/crm_domain';

  interface Props {
    formData: ClientFormData;
    errors: Record<string, string[]>;
    countries: Array<{ name: string; code: string; flag: string }>;
    countriesLoading: boolean;
    countriesError?: string | null;
    onFetchCountries?: () => Promise<void>;
  }

  let { 
    formData, 
    errors = {}, 
    countries = [], 
    countriesLoading = false,
    countriesError = null,
    onFetchCountries = undefined
  }: Props = $props();

  let countryOptions = $derived((countries || []).map((c: any) => ({ label: c.name, value: c.code, flag: c.flag })));
</script>

<div class="space-y-6">
  <!-- Section 2: Individual Client Info -->
  <section class="border rounded-lg overflow-hidden shadow-sm">
    <div class="bg-muted/10 px-4 py-2 border-b">
      <h2 class="text-sm font-semibold uppercase tracking-wider text-muted-foreground">2. Client Personal Details</h2>
    </div>
    <div class="p-4 space-y-4">
      <div>
        <Label for="client-name" class="block text-sm font-medium">Full Name (Contact Person) <span class="text-rose-600">*</span></Label>
        <Input 
          id="client-name" 
          name="client[name]" 
          required 
          bind:value={formData.name} 
          class={`w-full ${hasError(errors, 'name') ? 'border-rose-600' : ''}`} 
        />
        {#if hasError(errors, 'name')}
          <div class="text-rose-600 text-sm mt-1">{errors['name']?.[0]}</div>
        {/if}
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <Label for="client-email" class="block text-sm font-medium">Personal/Work Email</Label>
          <Input 
            id="client-email" 
            name="client[email]" 
            type="email" 
            bind:value={formData.email} 
            class={`w-full ${hasError(errors, 'email') ? 'border-rose-600' : ''}`} 
          />
          {#if hasError(errors, 'email')}
            <div class="text-rose-600 text-sm mt-1">{errors['email']?.[0]}</div>
          {/if}
        </div>

        <div>
          <Label for="client-phone" class="block text-sm font-medium">Phone Number</Label>
          <Input 
            id="client-phone" 
            name="client[phone]" 
            bind:value={formData.phone} 
            class={`w-full ${hasError(errors, 'phone') ? 'border-rose-600' : ''}`} 
          />
          {#if hasError(errors, 'phone')}
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
          <Input 
            id="client-company" 
            name="client[company_name]" 
            required 
            bind:value={formData.companyName} 
            class={`w-full bg-background ${hasError(errors, 'company_name') ? 'border-rose-600' : ''}`} 
          />
          {#if hasError(errors, 'company_name')}
            <div class="text-rose-600 text-sm mt-1">{errors['company_name']?.[0]}</div>
          {/if}
        </div>

        <div>
          <Label for="client-company-id" class="block text-sm font-medium">Company Registration ID <span class="text-rose-600">*</span></Label>
          <Input 
            id="client-company-id" 
            name="client[company_id]" 
            required 
            bind:value={formData.companyId} 
            class={`w-full bg-background ${hasError(errors, 'company_id') ? 'border-rose-600' : ''}`} 
          />
          {#if hasError(errors, 'company_id')}
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
          <select 
            id="client-country" 
            name="client[country]" 
            bind:value={formData.selectedCountry} 
            class={`w-full border rounded px-3 py-2 bg-background ${hasError(errors, 'country') ? 'border-rose-600' : ''}`}
          >
            <option value="">Select a country</option>
            {#each countryOptions as opt}
              <option value={opt?.value}>{opt?.flag} {opt?.label}</option>
            {/each}
          </select>
        {/if}
        {#if countriesError}
          <div class="text-rose-600 text-sm mt-1">
            Error loading countries: {countriesError} 
            {#if onFetchCountries}
              <button type="button" class="ml-2 underline" onclick={onFetchCountries}>Retry</button>
            {/if}
          </div>
        {/if}
        {#if hasError(errors, 'country')}
          <div class="text-rose-600 text-sm mt-1">{errors['country']?.[0]}</div>
        {/if}
      </div>

      <fieldset class="border p-4 rounded-md bg-background/50">
        <legend class="px-2 text-sm font-medium text-muted-foreground">Business Address</legend>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2 mt-2">
          <div class="md:col-span-2">
            <Label for="client-street" class="block text-sm">Street</Label>
            <Input 
              id="client-street" 
              name="client[address][street]" 
              bind:value={formData.street} 
              placeholder="e.g. 123 Business Road" 
              class="w-full" 
            />
          </div>
          <div>
            <Label for="client-city" class="block text-sm">City</Label>
            <Input 
              id="client-city" 
              name="client[address][city]" 
              bind:value={formData.city} 
              placeholder="City" 
            />
          </div>
          <div>
            <Label for="client-postal" class="block text-sm">Postal Code</Label>
            <Input 
              id="client-postal" 
              name="client[address][postal_code]" 
              bind:value={formData.postal} 
              placeholder="Code" 
            />
          </div>
        </div>
      </fieldset>
    </div>
  </section>
</div>
