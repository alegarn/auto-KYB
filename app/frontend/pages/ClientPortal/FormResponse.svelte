<script lang="ts">
  import { client_portal_form_response_path } from '@/routes'
  import FormFieldRenderer from '../../components/FormFieldRenderer.svelte'

  const props = $props()
  const form = $derived(props.form)
  const injectedOnSave = $derived(props.onSave)
  const hasInjectedHandler = $derived(typeof injectedOnSave === 'function')

  // form state keyed by field id
  let state = $state<Record<string, any>>({})

  // initialize
  $effect(() => {
    if (form?.form_fields) {
      for (const f of form.form_fields) {
        if (state[f.id] === undefined) state[f.id] = f.value ?? ''
      }
    }
  })

  function onChange(detail: { id: string; value: any }) {
    const { id, value } = detail
    const f = form.form_fields.find((x: any) => x.id === id)
    if (f?.type === 'number') {
      state[id] = value === '' ? null : Number(value)
    } else {
      state[id] = value
    }
  }

  function submit(e: SubmitEvent) {
    if (hasInjectedHandler) {
      e.preventDefault()
      const submitter = e.submitter as HTMLButtonElement | null
      const validate = submitter?.value === 'true'
      injectedOnSave?.({ data: state, validate })
    }
  }
</script>

<h1>{form.name}</h1>
<form method="post" action={client_portal_form_response_path()} onsubmit={submit}>
  <input type="hidden" name="_method" value="patch" />

  {#each form.form_fields as field (field.id)}
    <FormFieldRenderer
      {field}
      name={`form_response[data][${field.id}]`}
      onChange={onChange}
    />
  {/each}

  <button type="submit" name="form_response[validate]" value="false">Save</button>
  <button type="submit" name="form_response[validate]" value="true">Submit & Validate</button>
</form>