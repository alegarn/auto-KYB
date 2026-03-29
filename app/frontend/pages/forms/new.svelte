<script lang="ts">
  import { router, page } from '@inertiajs/svelte'
  import { Button } from "/components/ui/button/index.js"
  import { Input } from "/components/ui/input/index.js"
  import { Label } from "/components/ui/label/index.js"
  import FormBuilder from "/components/customs/FormBuilder.svelte"
  import Modal from '@/components/ui/modal.svelte'
  import CrmMappingModal from '@/components/customs/CrmMappingModal.svelte'
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
  import { forms_path } from '@/routes';

  const { errors: serverErrors, activeCrmProviders = [], crmProperties } = $props()

  let name = $state("")
  let fields = $state<FormField[]>([])
  let settings = $state<FormSettings>({})
  let clientError = $state("")
  let submitting = $state(false)
  let showMappingWarning = $state(false)
  let mappingValid = $state(true)
  let showCrmMappingModal = $state(false)
  let showUnmappedCrmWarning = $state(false)
  let showUnmappedCrmWarningModal = $state(false)
  const loadingProperties = $derived(crmProperties === undefined)
  // @ts-ignore
  const canUseCrm = $derived($page.props.auth?.user?.can_use_crm)
  const singleCrmProvider = $derived(getSingleActiveCrmProvider(activeCrmProviders))
  const singleCrmProviderName = $derived(singleCrmProvider ? crmProviderDisplayName(singleCrmProvider) : 'your CRM')
  const unmappedFields = $derived(singleCrmProvider && canUseCrm ? getUnmappedCrmFields(fields, singleCrmProvider) : [])
  const hasUnmappedCrmFields = $derived(unmappedFields.length > 0)

  // preview state
  let preview = $state(false)
  let results = $state<Record<string, any>>({})
  let outputFormat = $state('json')
  const formSettings = $derived<FormSettings>(settings || {})

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
    (fields || []).forEach((f: any, i: number) => {
      if (isLayoutField(f.field_type)) return;
      const key = `field_${f.id ?? f.position ?? i}`
      const val = fd.get(key)
      if (val === null) {
        data[f.id ?? f.position ?? i] = null
      } else {
        const s = String(val)
        if (f.field_type === "number") {
          data[f.id ?? f.position ?? i] = s === "" ? null : Number(s)
        } else {
          data[f.id ?? f.position ?? i] = s
        }
      }
    })

    results = data
    preview = false
  }

  function handleSubmit() {
    submitForm()
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
    router.post(forms_path(), {
      form: {
        name,
        structure: {
          settings,
          fields: fields.map((f, i) => ({
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

  function openCrmMapping() {
    showCrmMappingModal = true
    showUnmappedCrmWarningModal = false
  }

  $effect(() => {
    if (!singleCrmProvider || !hasUnmappedCrmFields) {
      showUnmappedCrmWarning = false
      showUnmappedCrmWarningModal = false
    }
  })
</script>

<section class="mx-auto max-w-7xl">
      <div class="mb-6 flex items-center justify-between">
        <h1 class="text-2xl font-semibold">Create Form</h1>
        <div class="flex gap-2">
          <Button type="button" variant="outline" onclick={cancel}>Cancel</Button>
          <Button type="button" onclick={handleSubmit} disabled={submitting}>
            {submitting ? 'Creating...' : 'Create Form'}
          </Button>
        </div>
      </div>

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
        {#if activeCrmProviders.length > 0 && canUseCrm}
          <Button type="button" variant="outline" size="sm" onclick={openCrmMapping}>🔌 CRM Sync Settings</Button>
        {/if}
      </div>

      {#if preview}
        <div
          class="rounded-lg border shadow-sm overflow-hidden mb-4"
          style:background-color={formSettings.form_background_color || '#ffffff'}
        >
          {#if formSettings.header_background_color}
            <div class="px-6 py-4" style:background-color={formSettings.header_background_color}>
              <h2 class="text-lg font-semibold">{name}</h2>
            </div>
          {/if}
          <form onsubmit={handlePreviewSubmit} class="p-6">
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
              style:background-color={formSettings.primary_color || '#2563eb'}
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
</section>

<Modal
  bind:showModal={showUnmappedCrmWarningModal}
  title="Some fields will not export to your CRM"
  description={`Quick KYB will save this form, but ${unmappedFields.length} field${unmappedFields.length === 1 ? '' : 's'} ${unmappedFields.length === 1 ? 'is' : 'are'} still set to Do not map for ${singleCrmProviderName}.`}
  confirmText="Save Form Anyway"
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

<CrmMappingModal
  bind:open={showCrmMappingModal}
  form={{}}
  {crmProperties}
  {loadingProperties}
  {fields}
  showTestAction={false}
  ontestcrm={() => {}}
  onsave={({ fields: updatedFields }: { fields: FormField[] }) => {
    fields = updatedFields
    showCrmMappingModal = false
  }}
/>
