<script lang="ts">
  import { getSharedAuth } from '@/lib/shared-auth'
  import { router, page } from '@inertiajs/svelte'
  import { Button } from "/components/ui/button/index.js"
  import { Input } from "/components/ui/input/index.js"
  import { Label } from "/components/ui/label/index.js"
  import FormBuilder from "/components/customs/FormBuilder.svelte"
  import FormFieldRenderer from "@/components/customs/FormFieldRenderer.svelte"
  import {
    crmProviderDisplayName,
    isLayoutField,
    singleActiveCrmProvider as getSingleActiveCrmProvider,
    unmappedCrmFields as getUnmappedCrmFields,
    type FormSettings,
  } from "@/components/customs/form-builder/types"
  import { Field, FieldLabel, FieldContent } from "/components/ui/field/index";
  import type { FormField } from "/components/customs/form-builder/types"
  import { form_path } from '@/routes';
  import Toast from "/components/customs/Toast.svelte"
  import Modal from '@/components/ui/modal.svelte';
  import CrmMappingModal from '@/components/customs/CrmMappingModal.svelte';

  let { form: initial, errors: serverErrors, error: serverError, crmProperties, activeCrmProviders = [], auth = {} } = $props()

  // Track if crmProperties is still being deferred/loaded
  const loadingProperties = $derived(crmProperties === undefined);
  const singleCrmProvider = $derived(getSingleActiveCrmProvider(activeCrmProviders));
  const singleCrmProviderName = $derived(singleCrmProvider ? crmProviderDisplayName(singleCrmProvider) : 'your CRM');

  let name = $state("")
  let fields = $state<FormField[]>([])
  let settings = $state<FormSettings>({})
  let clientError = $state("")
  let submitting = $state(false)
  let showMappingWarning = $state(false)
  let mappingValid = $state(true)
  let showUnmappedCrmWarning = $state(false)
  let showUnmappedCrmWarningModal = $state(false)
  const sharedAuth = getSharedAuth()
  const canUseCrm = $derived(sharedAuth?.features?.crm?.allowed)
  const unmappedFields = $derived(singleCrmProvider && canUseCrm ? getUnmappedCrmFields(fields, singleCrmProvider) : [])
  const hasUnmappedCrmFields = $derived(unmappedFields.length > 0)

  // Sync state with props
  $effect(() => {
    name = initial?.name || "";
    fields = (initial?.form_fields || []).map((f: any, i: number) => ({
      id: f.id,
      label: f.label,
      field_type: f.field_type,
      required: !!f.required,
      position: f.position || i + 1,
      metadata: f.metadata || {},
    }));
    settings = initial?.structure?.settings || {};
  });

  // preview state
  let preview = $state(false)
  let results = $state<Record<string, any>>({})
  let outputFormat = $state('json')
  // @ts-ignore: Property 'toast' does not exist on type 'FlashData'
  const flashToast: { message?: string; type?: string } | null = $derived($page?.flash?.toast ?? null)
  
  // CRM Mapping Dummy State
  let showCrmMappingModal = $state(false);
  let testingCrm = $state(false);
  let testCrmSuccess = $state(false);


  function formattedResults(outputFormat: string, results: Record<string, any>): string {
    try {
      const flds = (fields || []).filter((f: any) => !isLayoutField(f.field_type))

      if (outputFormat === 'json') {
        const out: Record<string, any> = {}
        flds.forEach((f: any, i: number) => {
          const key = f.metadata?.export_key || (f.label != null ? String(f.label) : String(f.id ?? f.position ?? i))
          const val = results[f.id ?? f.position ?? i]
          out[key] = val === undefined ? null : val
        })
        return JSON.stringify(out, null, 2)
      }

      const rows: string[][] = [["label", "value"]]
      flds.forEach((f: any, i: number) => {
        const val = results[f.id ?? f.position ?? i]
        let s = val === null || val === undefined ? '' : String(val)
        if (s.includes('"') || s.includes(',') || s.includes('\n')) {
          s = '"' + s.replace(/"/g, '""') + '"'
        }
        const key = f.metadata?.export_key || String(f.label)
        rows.push([key, s])
      })
      return rows.map(r => r.join(',')).join('\n')
    } catch (e) {
      return String(results)
    }
  }

  function handlePreviewSubmit(e: Event) {
    e.preventDefault()
    const formEl = (e.currentTarget || e.target) as HTMLFormElement
    if (!formEl.checkValidity()) {
      formEl.reportValidity()
      return
    }

    const fd = new FormData(formEl)
    const data: Record<string, any> = {};
    (fields || []).forEach((f: any) => {
      if (isLayoutField(f.field_type)) return;
      const key = `field_${f.id ?? f.position}`
      const val = fd.get(key)
      if (val === null) {
        data[f.id ?? f.position] = null
      } else {
        const s = String(val)
        if (f.field_type === "number") {
          data[f.id ?? f.position] = s === "" ? null : Number(s)
        } else {
          data[f.id ?? f.position] = s
        }
      }
    })

    results = data
    preview = false
  }

  function handleSubmit() {
    submitForm();
  }

  function submitForm(options: { skipUnmappedCrmWarning?: boolean } = {}) {
    clientError = ""
    if (!name.trim()) {
      clientError = "Name is required"
      return
    }

    if (!mappingValid) {
      clientError = "Not all fields are unique for export mapping."
      showMappingWarning = true
      return
    }

    if (!options.skipUnmappedCrmWarning && singleCrmProvider && hasUnmappedCrmFields) {
      showUnmappedCrmWarning = true
      showUnmappedCrmWarningModal = true
      return
    }

    showMappingWarning = false
    showUnmappedCrmWarning = false
    showUnmappedCrmWarningModal = false

    submitting = true
    router.patch(form_path(initial?.id), {
      form: {
        name,
        structure: {
          settings,
          fields: fields.map((f, i) => ({
            ...(f.id ? { id: f.id } : {}),
            label: f.label,
            field_type: f.field_type,
            required: f.required,
            position: i + 1,
            metadata: f.metadata || {},
          })),
        },
      },
    } as any, {
      preserveState: true,
      onFinish: () => { submitting = false },
    })
  }

  function cancel() {
    history.back()
  }

  // CRM Mapping Modal functions
  function openCrmMapping() {
    showCrmMappingModal = true;
    testCrmSuccess = false;
    showUnmappedCrmWarningModal = false;
  }

  function closeCrmMapping() {
    showCrmMappingModal = false;
  }

  async function sendTestCrmData(updatedFields?: FormField[]) {
    testingCrm = true;
    try {
      const csrf = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '';
      
      const targetFields = updatedFields || fields;
      const payload = {
        fields: targetFields.map((f, i) => ({
          ...(f.id ? { id: f.id } : {}),
          label: f.label,
          field_type: f.field_type,
          required: f.required,
          position: i + 1,
          metadata: f.metadata || {},
        }))
      };
      
      const response = await fetch(`/forms/${initial?.id}/test_crm_mapping`, {
        method: 'POST',
        headers: { 
          'X-CSRF-Token': csrf,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });
      if (response.ok) {
        testCrmSuccess = true;
        setTimeout(() => { testCrmSuccess = false; }, 3000);
      } else {
        const body = await response.json();
        alert(`Test export failed: ${body.error || 'Unknown error'}`);
      }
    } catch (e: any) {
      alert(`Request failed: ${e.message}`);
    } finally {
      testingCrm = false;
    }
  }

  $effect(() => {
    if (!singleCrmProvider || !hasUnmappedCrmFields) {
      showUnmappedCrmWarning = false
      showUnmappedCrmWarningModal = false
    }
  })
</script>

<section class="mx-auto w-full max-w-full">
  <div class="mb-6 flex items-center justify-between">
    <h1 class="text-2xl font-semibold">Edit Form</h1>
    <div class="flex gap-2">
      <Button type="button" variant="outline" onclick={cancel}>Cancel</Button>
      <Button type="button" onclick={handleSubmit} disabled={submitting}>
        {submitting ? 'Saving...' : 'Save Changes'}
      </Button>
    </div>
  </div>

  {#if flashToast}
    <Toast message={flashToast.message} type={flashToast.type ?? 'notice'} />
  {/if}

  {#if serverError}
    <div class="mb-4 rounded-md border border-destructive/30 bg-destructive/5 px-4 py-3">
      <p class="text-sm text-destructive">{serverError}</p>
    </div>
  {/if}

  {#if serverErrors}
    {#if Array.isArray(serverErrors) && serverErrors.length}
      <div class="mb-4 rounded-md border border-destructive/30 bg-destructive/5 px-4 py-3">
        {#each serverErrors as msg}
          <p class="text-sm text-destructive">{msg}</p>
        {/each}
      </div>
    {:else if typeof serverErrors === 'object'}
      {#each Object.values(serverErrors) as msg}
        <p class="mb-4 text-sm text-destructive">{msg}</p>
      {/each}
    {/if}
  {/if}

  {#if clientError}
    <p class="mb-4 text-sm text-destructive">{clientError}</p>
  {/if}

  <div class="mb-6 max-w-md">
    <Label for="form-name" class="mb-1.5 block text-sm font-medium">Form Name</Label>
    <Input id="form-name" bind:value={name} placeholder="Enter form name" />
  </div>

  <div class="mb-4 flex items-center justify-between">
    <div class="flex items-center gap-2">
      <button type="button" class="px-3 py-1 rounded" class:font-semibold={!preview} onclick={() => { preview = false; results = {} }}>
        Edit
      </button>
      <button type="button" class="px-3 py-1 rounded" class:font-semibold={preview} onclick={() => { preview = true; results = {} }}>
        Preview
      </button>
    </div>
    {#if canUseCrm}
      <Button type="button" variant="outline" size="sm" onclick={openCrmMapping}> 🔌 CRM Sync Settings</Button>
    {/if}
  </div>

  {#if preview}
    <div
      class="rounded-lg border shadow-sm overflow-hidden mb-4 w-full"
      style:background-color={settings.form_background_color || '#ffffff'}
    >
      {#if settings.header_background_color}
        <div class="px-6 py-4" style:background-color={settings.header_background_color}>
          <h2 class="text-lg font-semibold">{name}</h2>
        </div>
      {/if}
      <form onsubmit={handlePreviewSubmit} class="p-6 w-full">
        {#each fields as field (field['id'] ?? field['position'])}
          {#if isLayoutField(field.field_type)}
            <FormFieldRenderer
              id={field['id'] ?? `field_${field['position']}`}
              label={field['label']}
              type={field.field_type || 'text'}
              required={false}
              inputOnly={true}
              metadata={field.metadata}
            />
          {:else}
            <Field class="mb-4">
              <FieldLabel for={`field_${field['id'] ?? field['position']}`}>{field['label']}{#if field['required']}*{/if}</FieldLabel>
              <FieldContent>
                <FormFieldRenderer
                  id={`field_${field['id'] ?? field['position']}`}
                  label={field['label']}
                  type={field.field_type || 'text'}
                  required={field.required}
                  name={`field_${field['id'] ?? field['position']}`}
                  value={''}
                  inputOnly={true}
                  onChange={()=>{}}
                  metadata={field.metadata}
                />
              </FieldContent>
            </Field>
          {/if}
        {/each}

        <button
          type="submit"
          class="mt-4 rounded-md px-4 py-2 text-sm font-medium text-white transition-colors hover:opacity-90"
          style:background-color={settings.primary_color || '#2563eb'}
        >
          Submit Preview
        </button>
      </form>
    </div>
  {:else}
    {#if Object.keys(results || {}).length > 0}
      <div>
        <h2>Preview Results</h2>
        <div class="flex items-center gap-2 mb-2">
          <button type="button" class="px-3 py-1 rounded bg-gray-100" onclick={() => (outputFormat = 'json')}>JSON</button>
          <button type="button" class="px-3 py-1 rounded bg-gray-100" onclick={() => (outputFormat = 'csv')}>CSV</button>
          <div class="text-sm text-muted-foreground ml-2">Format: {outputFormat}</div>
        </div>
        <pre class="whitespace-pre-wrap break-words max-w-full overflow-auto">{formattedResults(outputFormat, results)}</pre>
        <div class="mt-4">
          <button type="button" class="px-3 py-1 rounded" onclick={() => { preview = true; results = {} }}>Back to Preview</button>
        </div>
      </div>
    {:else}
      <FormBuilder
        bind:fields
        bind:settings
        {showMappingWarning}
        showCrmMappingWarning={showUnmappedCrmWarning}
        crmMappingWarningProviderName={singleCrmProviderName}
        unmappedCrmFieldLabels={unmappedFields.map((field) => field.label || 'Unnamed field')}
        onopencrmmapping={openCrmMapping}
        onmappingvaliditychange={(isValid) => {
          mappingValid = isValid
          if (isValid) {
            showMappingWarning = false
            if (clientError === 'Not all fields are unique for export mapping.') {
              clientError = ''
            }
          }
        }}
      />
    {/if}
  {/if}

  <CrmMappingModal
    bind:open={showCrmMappingModal}
    form={initial}
    {crmProperties}
    {loadingProperties}
    {fields}
    onsave={({ fields: updatedFields }: { fields: FormField[] }) => {
      fields = updatedFields;
      closeCrmMapping();
      handleSubmit();
    }}
    ontestcrm={sendTestCrmData}
    {testingCrm}
    {testCrmSuccess}
  />

  <Modal
    bind:showModal={showUnmappedCrmWarningModal}
    title="Some fields will not export to your CRM"
    description={`Quick KYB will save this form, but ${unmappedFields.length} field${unmappedFields.length === 1 ? '' : 's'} ${unmappedFields.length === 1 ? 'is' : 'are'} still set to Do not map for ${singleCrmProviderName}.`}
    confirmText="Save Changes Anyway"
    confirmTone="default"
    onConfirm={() => submitForm({ skipUnmappedCrmWarning: true })}
  >
    {#snippet children()}
      <div class="space-y-3 text-sm text-muted-foreground">
        <p>Those fields will not be exported to {singleCrmProviderName} until you assign a CRM field mapping.</p>
        <p>
          <button type="button" class="font-medium text-primary underline underline-offset-4" onclick={openCrmMapping}>
            Open CRM field mapping
          </button>
          to update the mapping before saving.
        </p>
      </div>
    {/snippet}
  </Modal>
</section>
