<script lang="ts">
  import { Form as InertiaForm, router, page } from '@inertiajs/svelte';
  import { onMount } from 'svelte';
  import Button from '/components/ui/button/button.svelte';
  import Input from '/components/ui/input/input.svelte';
  import { Label } from '/components/ui/label/index.js';
  import Toast from '@/components/customs/Toast.svelte';
  import CrmMatchBanner from '/components/CrmMatchBanner.svelte';
  import { client_path } from '@/routes';
  import { fetchCountriesData } from '/lib/countries';

  let {
    client = {},
    errors = {},
    forms = [],
    current_form_id = null,
    confirm_message = null,
    attempted_form_id = null,
    has_crm_link = false,
    has_active_crm_connection = false,
    confirm_replace_required = false } = $props();

  // modal and form state
  let showConfirm = $state({ open: false, continue: false });
  let confirmDialog: HTMLElement | null = $state(null);
  let previouslyFocused: HTMLElement | null = $state(null);

  function modalOpen() {
    const opening = !showConfirm?.open;
    showConfirm.open = opening;
    if (opening) {
      previouslyFocused = document.activeElement as HTMLElement | null;
      setTimeout(() => confirmDialog?.focus(), 0);
    } else {
      setTimeout(() => previouslyFocused?.focus(), 0);
    }
  }

  function modalContinue() {
    showConfirm.open = false;
    showConfirm.continue = true;
    confirmedReplace = true;
    // Use router.flash to set client-side flash for Inertia (preferred API)
    try {
      router.flash('toast', { message: confirm_message || 'You can update the form, but the form responses will be erased', type: 'alert' })
    } catch (err) {
      // fallback: merge into props if router.flash isn't available for some reason
      try {
        router.replace({ props: (p: any) => ({ ...p, flash: { toast: { message: confirm_message || 'You can update the form, but the form responses will be erased', type: 'alert' } } }) })
      } catch (err2) {
        console.error('Failed to set flash toast', err2);
      }
    }
    setTimeout(() => previouslyFocused?.focus(), 0);
  }

  function handleFormSelectPointerDown(event: PointerEvent) {
    if (client?.status !== "active") return;
    if (showConfirm?.continue) return;
    if (showConfirm?.open) return;
    event.preventDefault();
    showConfirm.open = true;
    previouslyFocused = document.activeElement as HTMLElement | null;
    setTimeout(() => confirmDialog?.focus(), 0);
  }

  function handleFormSelectKeyDown(event: KeyboardEvent) {
    const code = event.key;
    if (code !== 'Enter' && code !== ' ' && code !== 'Spacebar') return;
    if (client?.status !== "active") return;
    if (showConfirm?.continue) return;
    if (showConfirm?.open) return;
    event.preventDefault();
    showConfirm.open = true;
    previouslyFocused = document.activeElement as HTMLElement | null;
    setTimeout(() => confirmDialog?.focus(), 0);
  }

  // selected form the user may pick (local state so we can bind and update)
  let selectedForm = $state(attempted_form_id || current_form_id || (forms && forms.length ? forms[0]?.id : null));

  let countries = $state<Array<{ name: string; code: string; flag: string }>>([]);
  let countryOptions = $derived(
    (countries || []).map((c: any) => ({ label: c.name, value: c.code, flag: c.flag }))
  );
  // preserve server-sent initial value but allow user to change
  let selectedCountry = $state(client?.country || '');

  let countriesLoading = $state(false);
  let countriesError = $state(null);

  async function fetchCountries() {
    countriesLoading = true;
    countriesError = null;
    try {
      const data = await fetchCountriesData();
      countries = data;
      if (selectedCountry && !countries.find((x) => String(x.code) === String(selectedCountry))) {
        countries = [{ name: selectedCountry, code: selectedCountry, flag: '🏳️' }, ...countries];
      }
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

  // form submission state
  let confirmedReplace = $state(false);

  // @ts-ignore: Property 'toast' does not exist on type 'FlashData'
  const flashToast: { message?: string; type?: string } | null = $derived($page?.flash?.toast ?? null)
  const flashClasses: string = $derived(
    flashToast
      ? flashToast?.type === 'notice'
        ? 'mb-4 rounded-md p-4 text-sm bg-green-50 text-green-700'
        : 'mb-4 rounded-md p-4 text-sm bg-red-50 text-red-700'
      : ''
  )

  // currently linked form (if provided via client props)
  const currentLinkedForm = $derived.by(() => {
    const linkedId = current_form_id || client?.client_form_id || client?.form_id || client?.form?.id;
    return (forms && forms.length) ? forms.find((f: any) => String(f.id) === String(linkedId)) : null;
  });

  const hasError = (field: string) => {
    if (!errors) return false;
    if (Array.isArray(errors)) return false;
    return (errors[field] && errors[field].length) || false;
  };
</script>

<section class="p-6 max-w-3xl mx-auto">
      <header class="mb-4">
        <h1 class="text-2xl font-semibold">Edit client</h1>
        <p class="text-sm text-muted-foreground">{client?.email}</p>
      </header>

      {#if has_active_crm_connection && !has_crm_link && client?.email}
        <CrmMatchBanner clientId={client.id} clientEmail={client.email} />
      {/if}

      {#if flashToast}
        <Toast message={flashToast.message ?? confirm_message ?? 'Confirmed'} type={flashToast.type ?? 'notice'} />
      {/if}

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

      <InertiaForm id="client-edit-form" method="patch" action={`/clients/${client?.id}`}>
        <!-- form mapping: show current linked form and allow changing via a dropdown (replaces previous Change button) -->
        {#if forms && forms.length}
          <div class="mt-4">
            <Label for="client-form" class="block text-sm font-medium">Linked form</Label>
            <div class="mt-1">
              {#if client?.status === "validated"}
                {#if currentLinkedForm}
                  <span class="text-sm text-muted-foreground">{currentLinkedForm?.name} <span class="ml-2 text-xs px-2 py-0.5 rounded bg-green-100 text-green-800">validated</span></span>
                  <input type="hidden" name="client_form[form_id]" value={currentLinkedForm?.id ?? ''} />
                {:else}
                  <span class="text-sm text-muted-foreground"><em>None</em></span>
                {/if}
              {:else}
                <select id="client-form" data-testid="client-form" name="client_form[form_id]" bind:value={selectedForm}
                  onpointerdown={handleFormSelectPointerDown}
                  onkeydown={handleFormSelectKeyDown}
                  class="mt-2 block w-full rounded border px-2 py-1">
                  <option value="">-- None --</option>
                  {#each forms as f}
                    <option value={f.id}>{f.name}</option>
                  {/each}
                </select>
              {/if}
            </div>
          </div>
        {/if}

        <input type="hidden" name="client_form[confirm_replace]" value={confirmedReplace ? 'true' : 'false'} />
        <div class="space-y-4 max-w-2xl">
          <div>
            <Label for="client-name" class="block text-sm font-medium">Name</Label>
            <Input id="client-name" name="client[name]" value={client?.name} class={`w-full ${hasError('name') ? 'border-rose-600' : ''}`} />
            {#if hasError('name')}
              <div class="text-rose-600 text-sm mt-1">{errors['name']?.[0]}</div>
            {/if}
          </div>

          <div>
            <Label for="client-company" class="block text-sm font-medium">Company name</Label>
            <Input id="client-company" name="client[company_name]" value={client?.company_name} class={`w-full ${hasError('company_name') ? 'border-rose-600' : ''}`} />
            {#if hasError('company_name')}
              <div class="text-rose-600 text-sm mt-1">{errors['company_name']?.[0]}</div>
            {/if}
          </div>

          <div>
            <Label for="client-company-id" class="block text-sm font-medium">Company ID</Label>
            <Input id="client-company-id" name="client[company_id]" value={client?.company_id} class={`w-full ${hasError('company_id') ? 'border-rose-600' : ''}`} />
            {#if hasError('company_id')}
              <div class="text-rose-600 text-sm mt-1">{errors['company_id']?.[0]}</div>
            {/if}
          </div>

          <div>
            <Label for="client-email" class="block text-sm font-medium">Email</Label>
            <Input id="client-email" name="client[email]" type="email" value={client?.email} class={`w-full ${hasError('email') ? 'border-rose-600' : ''}`} />
            {#if hasError('email')}
              <div class="text-rose-600 text-sm mt-1">{errors['email']?.[0]}</div>
            {/if}
          </div>

          <div>
            <Label for="client-phone" class="block text-sm font-medium">Phone</Label>
            <Input id="client-phone" name="client[phone]" value={client?.phone} class={`w-full ${hasError('phone') ? 'border-rose-600' : ''}`} />
            {#if hasError('phone')}
              <div class="text-rose-600 text-sm mt-1">{errors['phone']?.[0]}</div>
            {/if}
          </div>

          <div>
            <Label for="client-country" class="block text-sm font-medium">Company's country</Label>
            <select id="client-country" name="client[country]" bind:value={selectedCountry} class={`w-full border rounded px-3 py-2 bg-background ${hasError('country') ? 'border-rose-600' : ''}`} disabled={countriesLoading}>
              {#if countriesLoading}
                <option>Loading countries...</option>
              {:else}
                <option value="">Select a country</option>
                {#each countryOptions as opt}
                  <option value={opt.value}>{opt.flag} {opt.label}</option>
                {/each}
              {/if}
            </select>
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
                <Input id="client-street" name="client[address][street]" value={client?.address?.street} />
              </div>
              <div>
                <Label for="client-city" class="block text-sm">City</Label>
                <Input id="client-city" name="client[address][city]" value={client?.address?.city} />
              </div>
              <div>
                <Label for="client-postal" class="block text-sm">Postal code</Label>
                <Input id="client-postal" name="client[address][postal_code]" value={client?.address?.postal_code} />
              </div>
            </div>
          </fieldset>
        </div>

        <div class="mt-6 flex gap-2 items-center">
          <Button type="submit" class="btn">Update client</Button>
          <Button href={client_path(client?.id)} class="btn btn-ghost">Cancel</Button>
        </div>
      </InertiaForm>

      {#if showConfirm?.open && !showConfirm?.continue && client?.status === "active"}
        <div class="fixed inset-0 z-[999] flex items-center justify-center">
          <div class="absolute inset-0 bg-black/50" onclick={modalOpen} aria-hidden="true"></div>
          <div bind:this={confirmDialog} class="relative z-[1000] bg-white rounded p-6 max-w-lg w-full shadow-lg" role="dialog" aria-modal="true" aria-labelledby="confirm-title" tabindex="-1">
            <h2 id="confirm-title" class="text-lg font-semibold mb-2">Please confirm</h2>
            <p class="mb-4">{confirm_message || "Are you sure you want to replace the client's linked form? This will delete existing form responses."}</p>
            <div class="flex gap-2 justify-end">
              <button type="button" class="px-4 py-2 border rounded" onclick={modalOpen}>Cancel</button>
              <button type="button" class="px-4 py-2 bg-rose-600 text-white rounded" onclick={modalContinue}>
                Continue
              </button>
            </div>
          </div>
        </div>
      {/if}
</section>
