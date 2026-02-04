<script lang="ts">
  import FormFieldRenderer from '../../components/FormFieldRenderer.svelte'
  export let form: { id: string; name: string; form_fields: Array<any> }
  // callback prop for Svelte 5: onSave
  export let onSave: (payload: any) => void = () => {}

  // form state keyed by field id
  let state: Record<string, any> = {}

  // initialize
  $: if (form?.form_fields) {
    for (const f of form.form_fields) {
      if (state[f.id] === undefined) state[f.id] = f.value ?? ''
    }
  }

  function onChange(e: CustomEvent) {
    const { id, value } = e.detail
    const f = form.form_fields.find((x: any) => x.id === id)
    if (f?.type === 'number') {
      state[id] = value === '' ? null : Number(value)
    } else {
      state[id] = value
    }
  }

  function save() {
    onSave({ data: state })
  }
</script>

<h1>{form.name}</h1>
{#each form.form_fields as field (field.id)}
  <FormFieldRenderer {field} on:change={onChange} />
{/each}

<button on:click={save}>Save</button>