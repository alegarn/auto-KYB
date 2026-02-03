<script lang="ts">
  import { Form, page } from '@inertiajs/svelte'
  import { Button } from "/components/ui/button/index.js"
  import { Input } from "/components/ui/input/index.js"
  import { Checkbox } from "/components/ui/checkbox/index.js"
  import { Label } from "/components/ui/label/index.js"
  import BasicDropdown from '/components/ui/dropdown/basic-dropdown.svelte'
  import { forms_path } from '@/routes';

  let name = $state("")
  let fields = $state<Array<{ label: string; field_type: string; required: boolean }>>([])

  const { errors: serverErrors } = $props()

  let clientErrors = $state<{ name?: string; fieldErrors: Array<{ label?: string; field_type?: string }> }>({ fieldErrors: [] })

  function addField() {
    fields = [...fields, { label: '', field_type: 'text', required: false }]
  }

  function removeField(index: number) {
    fields = fields.filter((_, i) => i !== index)
  }

  function updateField(index: number, key: keyof typeof fields[number], value: any) {
    const next = fields.slice()
    // @ts-ignore - keep simple copy update
    next[index] = { ...next[index], [key]: value }
    fields = next
  }

  function validate(): boolean {
    let ok = true
    const nextFieldErrors: Array<{ label?: string; field_type?: string }> = []

    if (!name || !name.trim()) {
      clientErrors = { ...clientErrors, name: 'Name is required' }
      ok = false
    } else {
      clientErrors = { ...clientErrors, name: undefined }
    }

    fields.forEach((f, i) => {
      const fe: { label?: string; field_type?: string } = {}
      if (!f.label || !f.label.trim()) {
        fe.label = 'Label is required'
        ok = false
      }
      if (!['text', 'number', 'date'].includes(f.field_type)) {
        fe.field_type = 'Invalid type'
        ok = false
      }
      nextFieldErrors[i] = fe
    })

    clientErrors = { ...clientErrors, fieldErrors: nextFieldErrors }
    return ok
  }

  function handleSubmit(e: Event) {
    if (!validate()) {
      e.preventDefault()
      return
    }
    // allow native submit to proceed; server errors (if any) will be available
    // in `page.props.errors` (shared by the Rails adapter) and shown below
  }

  function cancel() {
    history.back()
  }
</script>

<section class="p-6">
  <h1>Create Form</h1>
  <Form action={forms_path()} method="post" on:submit={handleSubmit}>
    {#if serverErrors}
      {#if Array.isArray(serverErrors) && serverErrors.length}
        <ul class="text-red-600">
          {#each serverErrors as msg}
            <li>{msg}</li>
          {/each}
        </ul>
      {:else if serverErrors.name}
        <p class="text-red-600">{serverErrors.name}</p>
      {/if}
    {/if}
    {#if clientErrors.name}
      <p class="text-red-600">{clientErrors.name}</p>
    {/if}
    <div>
      <label for="name">Name</label>
      <Input id="name" bind:value={name} name="form[name]" />
    </div>

    <div>
      <h2>Fields</h2>
      {#each fields as field, i (i)}
        <div class="flex items-center gap-2">
              <Input
                bind:value={field.label}
                name={`form[structure][fields][${i}][label]`}
                placeholder="Label"
                oninput={(e: any) => { updateField(i, 'label', (e.target as HTMLInputElement).value); }}
              />
              {#if clientErrors.fieldErrors[i] && clientErrors.fieldErrors[i].label}
                <p class="text-red-600">{clientErrors.fieldErrors[i].label}</p>
              {/if}
              <div class="relative">
                <BasicDropdown
                  value={field.field_type}
                  items={[{ value: 'text', label: 'Text' }, { value: 'number', label: 'Number' }, { value: 'date', label: 'Date' }]}
                  on:select={(e: any) => updateField(i, 'field_type', e.detail.value)}
                />
                <input type="hidden" name={`form[structure][fields][${i}][field_type]`} value={field.field_type} />
                {#if clientErrors.fieldErrors[i] && clientErrors.fieldErrors[i].field_type}
                  <p class="text-red-600">{clientErrors.fieldErrors[i].field_type}</p>
                {/if}
              </div>
              <div class="flex items-center gap-2">
                <Checkbox
                  id={`required-${i}`}
                  name={`form[structure][fields][${i}][required]`}
                  checked={field.required}
                  onchange={(e) => updateField(i, 'required', (e.target as HTMLInputElement).checked)}
                />
                <Label for={`required-${i}`}>Required</Label>
              </div>
              <Button type="button" variant="destructive" onclick={() => removeField(i)}>Remove</Button>
        </div>
      {/each}
          <Button type="button" onclick={addField}>Add field</Button>
    </div>

    <div class="mt-4">
          <Button type="submit">Create</Button>
          <Button type="button" variant="outline" onclick={cancel}>Cancel</Button>
    </div>
  </Form>
</section>
