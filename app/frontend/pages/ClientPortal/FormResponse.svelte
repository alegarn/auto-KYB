<script lang="ts">
  import { Form } from '@inertiajs/svelte'
  import { client_portal_form_response_path } from '@/routes'
  import FormFieldRenderer from '../../components/FormFieldRenderer.svelte'
  import { Field, FieldLabel, FieldContent } from "/components/ui/field/index";
  import Button from '@/components/ui/button/button.svelte';
  
  const props = $props()
  const form = $derived(props.form)
  const injectedOnSave = $derived(props.onSave)
  const lastResponse = $derived(props.last_response)
  const hasInjectedHandler = $derived(typeof injectedOnSave === 'function')

  // form state keyed by field id
  type FlashMessage = { type: 'alert' | 'notice'; message?: string } | null
  let formState = $state<Record<string, any>>({})
  let flashMessage = $state<FlashMessage>(null)

  const flashClasses = $derived.by(() => {
    if (!flashMessage) return ''
    return flashMessage?.type === 'notice'
      ? 'mb-4 rounded-md p-4 text-sm bg-green-50 text-green-700'
      : 'mb-4 rounded-md p-4 text-sm bg-red-50 text-red-700'
  })

  // initialize
  $effect(() => {
    const lastData = lastResponse?.data || {}
    if (form?.form_fields) {
      for (const f of form.form_fields) {
        const key = String(f.id)
        const existing = lastData[key] ?? lastData[f.id]
        if (formState[f.id] === undefined) {
          formState[f.id] = existing ?? f.value ?? ''
        }
      }
    }
  })

  function onChange(detail: { id: string; value: any }) {
    const { id, value } = detail
    const f = form.form_fields.find((x: any) => x.id === id)
    if (f?.type === 'number') {
      formState[id] = value === '' ? null : Number(value)
    } else {
      formState[id] = value
    }
  }

  async function submit(e: SubmitEvent) {
    if (hasInjectedHandler) {
      e.preventDefault()
      const submitter = e.submitter as HTMLButtonElement | null
      const validate = submitter?.value === 'true'
      injectedOnSave?.({ data: formState, validate })
      return
    }

    e.preventDefault()
    flashMessage = null
    const submitter = e.submitter as HTMLButtonElement | null
    const validate = submitter?.value === 'true'

    const response = await fetch(client_portal_form_response_path(), {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      credentials: 'same-origin',
      body: JSON.stringify({ form_response: { data: formState, validate } }),
    })

    if (response?.status === 429) {
      const data = await response.json().catch(() => null)
      data?.error ? flashMessage = {type: "alert", message: data?.error} : null;
      return
    }

    if (response?.status === 403) {
      flashMessage = {
        type: "alert", 
        message: 'This form is locked or no longer available.'
      }
      return
    }

    if (response?.redirected) {
      window.location.href = response.url
      return
    }

    if (response?.ok) {
      const data = await response.json().catch(() => null)
      flashMessage =  {
          type: "notice", 
          message: data?.notice
        };
      return
    }


    if (!response?.ok) {
      flashMessage = {
        type: "alert", 
        message: 'Unable to submit the form right now. Your form may be revoked or locked. Please try again or contact your form provider.'
      }
    }
  }

</script>

<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
  <section class="max-w-3xl mx-auto rounded-lg border border-border bg-background p-6">
    {#if flashMessage}
      <div role="alert" class={flashClasses}>
        <span class="text-sm">{flashMessage?.message}</span>
      </div>
    {/if}

    <h1 class="text-xl font-semibold text-foreground">{form.name}</h1>

    <Form method="post" action={client_portal_form_response_path()} onsubmit={submit} class="mt-4 space-y-4">
      <input type="hidden" name="_method" value="patch" />

      {#each form.form_fields as field (field.id)}
        <Field>
          <FieldLabel for={field.id}>{field.label}{#if field.required}*{/if}</FieldLabel>
          <FieldContent>
            <FormFieldRenderer
              id={field.id}
              label={field.label}
              type={field.type}
              required={field.required}
              name={`form_response[data][${field.id}]`}
              value={formState[field.id] ?? ''}
              onChange={onChange}
            />
          </FieldContent>
        </Field>
      {/each}

      <div class="flex gap-3">
        <Button type="submit" name="form_response[validate]" value="false" class="inline-flex items-center rounded-md border border-border bg-background px-4 py-2 text-sm font-semibold">Save</Button>
        <Button type="submit" name="form_response[validate]" value="true" class="inline-flex items-center rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">Submit & Validate</Button>
      </div>
    </Form>
  </section>
</main>