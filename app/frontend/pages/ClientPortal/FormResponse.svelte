<script lang="ts">
  import { page, router } from '@inertiajs/svelte'
  import { client_portal_form_response_path } from '@/routes'
  import FormFieldRenderer from '../../components/FormFieldRenderer.svelte'
  
  const props = $props()
  const form = $derived(props.form)
  const injectedOnSave = $derived(props.onSave)
  const lastResponse = $derived(props.last_response)
  const hasInjectedHandler = $derived(typeof injectedOnSave === 'function')

  // form state keyed by field id
  type FlashMessage = { type: 'alert' | 'notice'; message?: string } | null
  let formState = $state<Record<string, any>>({})
  let flashMessage = $state<FlashMessage>(null)

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

{#if flashMessage}
  <div class="mb-4 rounded-md bg-{flashMessage?.type === 'alert' ? 'red' : 'green'}-50 p-4 text-sm text-{flashMessage?.type === 'alert' ? 'red' : 'green'}-700" role="alert">
    <span>{flashMessage?.message}</span>
  </div>
{/if}

<h1>{form.name}</h1>
<form method="post" action={client_portal_form_response_path()} onsubmit={submit}>
  <input type="hidden" name="_method" value="patch" />

  {#each form.form_fields as field (field.id)}
    <FormFieldRenderer
      id={field.id}
      label={field.label}
      type={field.type}
      required={field.required}
      name={`form_response[data][${field.id}]`}
      value={formState[field.id] ?? ''}
      onChange={onChange}
    />
  {/each}

  <button type="submit" name="form_response[validate]" value="false">Save</button>
  <button type="submit" name="form_response[validate]" value="true">Submit & Validate</button>
</form>