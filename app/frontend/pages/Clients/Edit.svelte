<script lang="ts">
  import { Form as InertiaForm, router, page } from '@inertiajs/svelte';
  import { onMount } from 'svelte';
  import Button from '/components/ui/button/button.svelte';
  import { Label } from '/components/ui/label/index.js';
  import Toast from '@/components/customs/Toast.svelte';
  import CrmMatchBanner from '/components/CrmMatchBanner.svelte';
  import CrmSyncWidget from '/components/CrmSyncWidget.svelte';
  import ClientFormFields from '@/components/ClientFormFields.svelte';
  import { client_path } from '@/routes';
  import { fetchCountriesData } from '/lib/countries';
  import { hasError } from '@/lib/utils';
  import { mapCrmPrefillToForm, type ClientFormData } from '@/lib/crm_domain';

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
  let selectedForm = $derived(attempted_form_id || current_form_id || (forms && forms.length ? forms[0]?.id : null));

  let countries = $state<Array<{ name: string; code: string; flag: string }>>([]);
  let countryOptions = $derived(
    (countries || []).map((c: any) => ({ label: c.name, value: c.code, flag: c.flag }))
  );
  // preserve server-sent initial value but allow user to change
  let selectedCountry = $derived(client?.country || '');

  let countriesLoading = $state(false);
  let countriesError = $state(null);

  // CRM sync state
  let crmSyncData = $state({ strategy: 'skip', sync_address_to_contact: false });

  function handleCrmSync(data: any) {
    crmSyncData = data;
  }

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

  // Mutable form state – $state (not $derived) so bind:value works reactively
  let formData = $state<ClientFormData>({
    name: client?.name || '',
    email: client?.email || '',
    phone: client?.phone || '',
    companyName: client?.company_name || '',
    companyId: client?.company_id || '',
    selectedCountry: client?.country || '',
    street: client?.address?.street || '',
    city: client?.address?.city || '',
    postal: client?.address?.postal_code || ''
  });

  async function fetchCrmDetails() {
    try {
      const resp = await fetch(`/clients/${client?.id}/crm_contact_details`);
      if (resp.ok) {
        const crmData = await resp.json();
        if (crmData) {
          const mapped = mapCrmPrefillToForm(crmData);
          Object.entries(mapped).forEach(([key, value]) => {
            if (value !== undefined) {
              formData[key as keyof ClientFormData] = value;
            }
          });
        }
      }
    } catch (err) {
      console.error('Failed to fetch CRM details', err);
    }
  }

  // form submission state
  let confirmedReplace = $state(false);

  // @ts-ignore: Property 'toast' does not exist on type 'FlashData'
  const flashToast: { message?: string; type?: string } | null = $derived($page?.flash?.toast ?? null)

  // currently linked form (if provided via client props)
  const currentLinkedForm = $derived.by(() => {
    const linkedId = current_form_id || client?.client_form_id || client?.form_id || client?.form?.id;
    return (forms && forms.length) ? forms.find((f: any) => String(f.id) === String(linkedId)) : null;
  });
</script>

<section class="p-6 max-w-3xl mx-auto">
      <header class="mb-4">
        <h1 class="text-2xl font-semibold">Edit client</h1>
        <p class="text-sm text-muted-foreground">{client?.email}</p>
      </header>

      {#if has_active_crm_connection && !has_crm_link}
        <CrmMatchBanner clientId={client.id} clientEmail={client.email} clientCompany={client.company_name} />
      {/if}

      {#if has_active_crm_connection && has_crm_link}
        <div class="mb-4 p-4 border rounded bg-muted/20 flex justify-between items-center">
          <div class="text-sm">
            <span class="font-medium text-blue-600">CRM Link Active</span>
            <p class="text-muted-foreground italic">You can fill missing fields with data from your CRM.</p>
          </div>
          
<button type="button" class="bg-primary/10 hover:bg-primary/20 text-primary border border-primary/20 px-3 py-1.5 text-sm rounded-md font-medium transition-colors" onclick={() => fetchCrmDetails()}>Complete with CRM data</button>
        </div>
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
        <div class="space-y-6 max-w-2xl">
          <!-- Section 1: Integration & Linked Form -->
          <section class="border rounded-lg overflow-hidden shadow-sm bg-muted/5">
            <div class="bg-muted/20 px-4 py-2 border-b">
              <h2 class="text-sm font-semibold uppercase tracking-wider text-muted-foreground">1. Integration & Form</h2>
            </div>
            <div class="p-4 space-y-4">
              {#if has_active_crm_connection}
                <div class="mb-4">
                  <CrmSyncWidget onSyncDataChanged={handleCrmSync} companyName={client?.company_name} />
                  <input type="hidden" name="crm[strategy]" value={crmSyncData.strategy} />
                  <input type="hidden" name="crm[sync_address_to_contact]" value={crmSyncData.sync_address_to_contact ? 'true' : 'false'} />
                </div>
              {/if}

              <!-- form mapping: show current linked form and allow changing via a dropdown (replaces previous Change button) -->
              {#if forms && forms.length}
                <div>
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
                        class={`mt-1 block w-full rounded border px-3 py-2 bg-background ${hasError(errors, 'form_id') ? 'border-rose-600' : ''}`}>
                        <option value="">-- None --</option>
                        {#each forms as f}
                          <option value={f.id}>{f.name}</option>
                        {/each}
                      </select>
                      {#if hasError(errors, 'form_id')}
                        <div class="text-rose-600 text-sm mt-1">{errors['form_id']?.[0]}</div>
                      {/if}
                    {/if}
                  </div>
                </div>
              {/if}
            </div>
          </section>

          <input type="hidden" name="client_form[confirm_replace]" value={confirmedReplace ? 'true' : 'false'} />
          
          <ClientFormFields 
            formData={formData} 
            {errors} 
            {countries} 
            countriesLoading={countriesLoading} 
            countriesError={countriesError}
            onFetchCountries={fetchCountries}
          />
        </div>

        <div class="mt-8 pt-6 border-t flex gap-3 items-center">
          <Button type="submit" class="btn px-8">Update Client Profile</Button>
          <Button href={client_path(client?.id)} class="btn btn-ghost text-muted-foreground">Cancel</Button>
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
