<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { client_portal_form_response_path } from '@/routes'
  import FormFieldRenderer from '@/components/customs/FormFieldRenderer.svelte'
  import { isLayoutField, type FormSettings } from '@/components/customs/form-builder/types'
  import { Field, FieldLabel, FieldContent } from "@/components/ui/field/index";
  import Button from '@/components/ui/button/button.svelte';

  // props ------------------------------------------------------------
  const props = $props()

  // derived props ------------------------------------------------------------
  const portalForm = $derived(props.form)
  const injectedOnSave = $derived(props.onSave)
  const lastResponse = $derived(props.last_response)
  const incomingFlash = $derived(props.flash_message)
  const hasInjectedHandler = $derived(typeof injectedOnSave === 'function')
  const formSettings = $derived<FormSettings>(portalForm?.structure?.settings || {})

  // form state keyed by field id ------------------------------------------------------------
  type FlashMessage = { type: 'alert' | 'notice'; message?: string } | null
  let baseState = $state<Record<string, any>>({})
  let baseVersion = $derived<number | null>(lastResponse?.version ?? null)
  let flashMessage = $state<FlashMessage>(null)
  let autosaveHelpers: null | typeof import('@/lib/form-response/autosave') = $state(null)
  let autosaveController: null | { schedule: () => void; cancel: () => void; flush: () => Promise<void> } = $state(null)
  let initialized = $state(false)
  let lastVersionSeen = $state<number | null>(null)

  const form = useForm<Record<string, any>>({})

  const flashClasses = $derived.by(() => {
    if (!flashMessage) return ''
    return flashMessage?.type === 'notice'
      ? 'mb-4 rounded-md p-4 text-sm bg-green-50 text-green-700'
      : 'mb-4 rounded-md p-4 text-sm bg-red-50 text-red-700'
  })

  function buildInitialState() {
    const data: Record<string, any> = {}
    const lastData = lastResponse?.data || {}
    if (portalForm?.form_fields) {
      for (const f of portalForm.form_fields) {
        if (isLayoutField(f.field_type ?? f.type)) continue
        const key = String(f.id)
        const existing = lastData[key] ?? lastData[f.id]
        data[key] = existing ?? f.value ?? ''
      }
    }
    return data
  }

  function currentData() {
    const data: Record<string, any> = {}
    if (portalForm?.form_fields) {
      for (const f of portalForm.form_fields) {
        if (isLayoutField(f.field_type ?? f.type)) continue
        const key = String(f.id)
        data[key] = ($form as Record<string, any>)[key] ?? ''
      }
    }
    return data
  }

  // initialize - skip layout fields as they don't collect data
  $effect(() => {
    if (!portalForm?.form_fields || initialized) return
    const initial = buildInitialState()
    $form.defaults(initial)
    for (const [key, value] of Object.entries(initial)) {
      ;($form as Record<string, any>)[key] = value
    }
    baseState = { ...initial }
    baseVersion = lastResponse?.version ?? null
    lastVersionSeen = baseVersion
    initialized = true
  })

  $effect(() => {
    if (!incomingFlash) return
    flashMessage = incomingFlash
  })

  $effect(() => {
    if (!lastResponse?.version) return
    if (lastVersionSeen === lastResponse.version) return
    lastVersionSeen = lastResponse.version
    baseVersion = lastResponse.version
    if (lastResponse?.data) {
      baseState = { ...baseState, ...lastResponse.data }
    }
  })

  // Functions ------------------------------------------------------------
  function onChange(detail: { id: string; value: any }) {
    const { id, value } = detail
    const f = portalForm.form_fields.find((x: any) => x.id === id)
    const fieldType = f?.field_type ?? f?.type
    if (fieldType === 'number') {
      ;($form as Record<string, any>)[id] = value === '' ? null : Number(value)
    } else {
      ;($form as Record<string, any>)[id] = value
    }

    if (!hasInjectedHandler) {
      ensureAutosave().then(() => autosaveController?.schedule())
    }
  }

  async function ensureAutosave() {
    if (autosaveHelpers) return
    autosaveHelpers = await import('@/lib/form-response/autosave')
    autosaveController = autosaveHelpers.createAutosave({
      onSave: () => savePartial(),
      delayMs: 3000,
      minIntervalMs: 3000,
    })
  }

  async function savePartial() {
    if (!autosaveHelpers) return
    const delta = autosaveHelpers.buildDelta(currentData(), baseState)
    if (Object.keys(delta).length === 0) return
    await sendSave({ data: delta, validate: false, partial: true })
  }

  async function sendSave(payload: { data: Record<string, any>; validate: boolean; partial: boolean }) {
    flashMessage = null
    autosaveController?.cancel()

    const options = {
      preserveScroll: true,
      preserveState: true,
      only: payload.partial ? ['last_response', 'flash_message'] : undefined,
      onSuccess: () => {
        if (payload.partial) {
          flashMessage = { type: 'notice', message: 'Form response saved successfully.' }
        }
      },
      onError: () => {
        flashMessage = {
          type: 'alert',
          message: 'Unable to submit the form right now. Please try again.'
        }
      }
    }

    $form
      .transform(() => ({
        form_response: {
          data: payload.data,
          validate: payload.validate,
          partial: payload.partial,
          base_version: baseVersion,
        }
      }))
      .patch(client_portal_form_response_path(), options)
  }

  async function submit(e: SubmitEvent) {
    if (hasInjectedHandler) {
      e.preventDefault()
      const submitter = e.submitter as HTMLButtonElement | null
      const validate = submitter?.value === 'true'
      injectedOnSave?.({ data: currentData(), validate })
      return
    }

    e.preventDefault()
    const submitter = e.submitter as HTMLButtonElement | null
    const validate = submitter?.value === 'true'
    const partial = !validate
    const data = partial && autosaveHelpers
      ? autosaveHelpers.buildDelta(currentData(), baseState)
      : currentData()

    if (partial && Object.keys(data).length === 0) {
      flashMessage = { type: 'notice', message: 'No changes to save.' }
      return
    }

    await sendSave({ data, validate, partial })
  }

</script>

<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
  <section
    class="max-w-3xl mx-auto rounded-lg border border-border overflow-hidden"
    style:background-color={formSettings.form_background_color || undefined}
  >
    {#if formSettings.header_background_color}
      <div class="px-6 py-4" style:background-color={formSettings.header_background_color}>
        <h1 class="text-xl font-semibold text-foreground">{portalForm.name}</h1>
      </div>
    {/if}

    <div class="p-6">
      {#if flashMessage}
        <div role="alert" class={flashClasses}>
          <span class="text-sm">{flashMessage?.message}</span>
        </div>
      {/if}

      {#if !formSettings.header_background_color}
        <h1 class="text-xl font-semibold text-foreground mb-4">{portalForm.name}</h1>
      {/if}

      <form onsubmit={submit} class="space-y-4" aria-busy={$form.processing}>
        {#each portalForm.form_fields as field (field.id ?? field.position)}
          {#if isLayoutField(field.field_type ?? field.type)}
            <FormFieldRenderer
              id={field.id ?? `field_${field.position}`}
              label={field.label}
              type={field.field_type ?? field.type}
              required={false}
              inputOnly={true}
              metadata={field.metadata}
            />
          {:else}
            <Field>
              <FieldLabel for={field.id}>{field.label}{#if field.required}*{/if}</FieldLabel>
              <FieldContent>
                <FormFieldRenderer
                  id={field.id}
                  label={field.label}
                  type={field.field_type ?? field.type}
                  required={field.required}
                  name={`form_response[data][${field.id}]`}
                  value={($form as Record<string, any>)[field.id] ?? ''}
                  inputOnly={true}
                  onChange={onChange}
                  metadata={field.metadata}
                />
              </FieldContent>
            </Field>
          {/if}
        {/each}

        <div class="flex gap-3">
          <Button type="submit" name="form_response[validate]" value="false" class="inline-flex items-center rounded-md border border-border bg-background px-4 py-2 text-sm font-semibold text-foreground">Save</Button>
          <button
            type="submit"
            name="form_response[validate]"
            value="true"
            class="inline-flex items-center rounded-md px-4 py-2 text-sm font-semibold text-white transition-colors hover:opacity-90"
            style:background-color={formSettings.primary_color || '#2563eb'}
          >
            Submit & Validate
          </button>
        </div>
      </form>
    </div>
  </section>
</main>