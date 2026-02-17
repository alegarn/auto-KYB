<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import { router, page } from '@inertiajs/svelte'
  import { Button } from "/components/ui/button/index.js"
  import { Input } from "/components/ui/input/index.js"
  import { Label } from "/components/ui/label/index.js"
  import FormBuilder from "/components/customs/FormBuilder.svelte"
  import FormFieldRenderer from "@/components/customs/FormFieldRenderer.svelte"
  import { isLayoutField, type FormSettings } from "@/components/customs/form-builder/types"
  import { Field, FieldLabel, FieldContent } from "/components/ui/field/index";
  import type { FormField } from "/components/customs/form-builder/types"
  import { form_path } from '@/routes';
  import Toast from "/components/customs/Toast.svelte"

  let { form: initial, errors: serverErrors, error: serverError, session_id } = $props()

  let name = $derived(initial?.name || "")
  let fields = $derived<FormField[]>(
    (initial?.form_fields || []).map((f: any, i: number) => ({
      id: f.id,
      label: f.label,
      field_type: f.field_type,
      required: !!f.required,
      position: f.position || i + 1,
      metadata: f.metadata || {},
    }))
  )
  let settings = $derived<FormSettings>(initial?.structure?.settings || {})
  let clientError = $state("")
  let submitting = $state(false)

  // preview state
  let preview = $state(false)
  let results = $state<Record<string, any>>({})
  let outputFormat = $state('json')
  const formSettings = $derived<FormSettings>(settings || {})
  // @ts-ignore: Property 'toast' does not exist on type 'FlashData'
  const flashToast: { message?: string; type?: string } | null = $derived($page?.flash?.toast ?? null)
  

  function formattedResults(outputFormat: string, results: Record<string, any>): string {
    try {
      const flds = (fields || []).filter((f: any) => !isLayoutField(f.field_type))

      if (outputFormat === 'json') {
        const out: Record<string, any> = {}
        flds.forEach((f: any) => {
          const key = f.label != null ? String(f.label) : String(f.id)
          const val = results[f.id]
          out[key] = val === undefined ? null : val
        })
        return JSON.stringify(out, null, 2)
      }

      const rows: string[][] = [["label", "value"]]
      flds.forEach((f: any) => {
        const val = results[f.id]
        let s = val === null || val === undefined ? '' : String(val)
        if (s.includes('"') || s.includes(',') || s.includes('\n')) {
          s = '"' + s.replace(/"/g, '""') + '"'
        }
        rows.push([String(f.label), s])
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
    clientError = ""
    if (!name.trim()) {
      clientError = "Name is required"
      return
    }

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
</script>

<Sidebar.Provider>
  <AppSidebar session_id={session_id} />
  <main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8 flex-grow">
    <Sidebar.Trigger class="mb-4" />
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

      <div class="mb-4 flex items-center gap-2">
        <button type="button" class="px-3 py-1 rounded" class:font-semibold={!preview} onclick={() => { preview = false; results = {} }}>
          Edit
        </button>
        <button type="button" class="px-3 py-1 rounded" class:font-semibold={preview} onclick={() => { preview = true; results = {} }}>
          Preview
        </button>
      </div>

      {#if preview}
        <div
          class="rounded-lg border shadow-sm overflow-hidden mb-4 w-full"
          style:background-color={formSettings.form_background_color || '#ffffff'}
        >
          {#if formSettings.header_background_color}
            <div class="px-6 py-4" style:background-color={formSettings.header_background_color}>
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
                  <FieldLabel for={`field_${field['id']}`}>{field['label']}{#if field['required']}*{/if}</FieldLabel>
                  <FieldContent>
                    <FormFieldRenderer
                      id={`field_${field['id']}`}
                      label={field['label']}
                      type={field.field_type || 'text'}
                      required={field.required}
                      name={`field_${field['id']}`}
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
          <FormBuilder bind:fields bind:settings />
        {/if}
      {/if}
    </section>
  </main>
</Sidebar.Provider>
