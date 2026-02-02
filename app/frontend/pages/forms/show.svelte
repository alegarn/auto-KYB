<script lang="ts">
  import Input from "/components/ui/input/input.svelte"
  import Button from "/components/ui/button/button.svelte"

  let { form } = $props()

  // preview mode and state
  let preview = $state(true)
  let results = $state<Record<string, any>>({})

  // derived: count of required fields that are filled in results
  const requiredCount = $derived(() => {
    const fields = form.form_fields || []
    return fields.filter((f: any) => f.required && results[f.id]).length
  })

  function handleSubmit(e: Event) {
    e.preventDefault()
    const formEl = (e.currentTarget || e.target) as HTMLFormElement
    const fd = new FormData(formEl)
    const data: Record<string, any> = {}
    ;(form.form_fields || []).forEach((f: any) => {
      const key = `field_${f.id}`
      const val = fd.get(key)
      data[f.id] = val === null ? null : String(val)
    })
    results = data
    preview = false
  }
</script>

<section class="p-6">
  <h1>{form.name}</h1>
  <p>{form.description}</p>

  {#if preview}
    <form onsubmit={handleSubmit}>
      {#each form.form_fields as field (field['id'])}
        <div class="mb-4">
          <label for={`field_${field['id']}`}>{field['label']}{#if field['required']}*{/if}</label>
          <Input id={`field_${field['id']}`} name={`field_${field['id']}`} />
        </div>
      {/each}

      <Button type="submit">Submit Preview</Button>
    </form>
  {:else}
    <div>
      <h2>Preview Results</h2>
      <pre>{JSON.stringify(results)}</pre>
    </div>
  {/if}
</section>
