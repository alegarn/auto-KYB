<script lang="ts">
  import { Form } from '@inertiajs/svelte'
  import Button from "/components/ui/button/button.svelte"
  import Input from "/components/ui/input/input.svelte"
  import BasicDropdown from '/components/ui/dropdown/basic-dropdown.svelte'
  import { form_path } from '@/routes';

  let { form: initial } = $props()

  let name = $derived<string>(initial?.name || "")
  let description = $derived<string>(initial?.description || "")
  let fields = $derived<Array<{ label: string; field_type: string; required: boolean }>>(initial?.form_fields?.map((f:any)=>({ label: f.label, field_type: f.field_type, required: f.required })) || [])

  const unsaved = $derived.by(() => name !== (initial?.name || '') || JSON.stringify(fields) !== JSON.stringify((initial?.form_fields||[]).map((f:any)=>({ label: f.label, field_type: f.field_type, required: f.required }))))

  $effect(() => {
    // very small auto-save draft mock: store in localStorage
    if (unsaved) {
      localStorage.setItem(`form_draft_${initial?.id || 'new'}`, JSON.stringify({ name, description, fields }))
    }
  })

  function addField() {
    fields = [...fields, { label: '', field_type: 'text', required: false }]
  }

  function removeField(index:number) {
    fields = fields.filter((_,i)=>i!==index)
  }

  function updateField(index:number, key:string, value:any) {
    const next = fields.slice()
    // @ts-ignore
    next[index] = { ...next[index], [key]: value }
    fields = next
  }

  function cancel() {
    history.back()
  }
</script>

<section class="p-6">
  <h1>Edit Form</h1>
  <Form action={form_path(initial?.id)} method="patch">
    <input type="hidden" name="_method" value="patch" />
    <div>
      <label for="name">Name</label>
      <Input id="name" bind:value={name} name="form[name]" />
    </div>
    <div>
      <label for="description">Description</label>
      <Input id="description" bind:value={description} name="form[description]" />
    </div>

    <div>
      <h2>Fields</h2>
      {#each fields as field, i (i)}
        <div class="flex items-center gap-2">
          <Input
            bind:value={field.label}
            name={`form[structure][fields][${i}][label]`}
            placeholder="Label"
            oninput={(e:any)=>updateField(i, 'label', (e.target as HTMLInputElement).value)}
          />
          <BasicDropdown
            value={field.field_type}
            items={[{ value: 'text', label: 'Text' }, { value: 'number', label: 'Number' }, { value: 'date', label: 'Date' }]}
            on:select={(e:any) => updateField(i, 'field_type', e.detail.value)}
          />
          <input type="hidden" name={`form[structure][fields][${i}][field_type]`} value={field.field_type} />
          <label class="flex items-center gap-2">
            <input
              type="checkbox"
              name={`form[structure][fields][${i}][required]`}
              checked={field.required}
              onchange={(e)=>updateField(i, 'required', (e.target as HTMLInputElement).checked)}
            />
            Required
          </label>
          <Button class="destructive" type="button" onclick={()=>removeField(i)}>Remove</Button>
        </div>
      {/each}
      <Button class="outline" type="button" onclick={addField}>Add field</Button>
    </div>

    <div class="mt-4">
      <Button type="submit">Save</Button>
      <Button type="button" variant="outline" onclick={cancel}>Cancel</Button>
    </div>
  </Form>
</section>
