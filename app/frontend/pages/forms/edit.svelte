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

<section class="p-6 max-w-3xl mx-auto">
  <h1 class="text-2xl font-semibold mb-4">Edit Form</h1>
  <Form action={form_path(initial?.id)} method="patch">
    <input type="hidden" name="_method" value="patch" />

    <div class="mb-4">
      <label for="name" class="block font-medium mb-1">Name</label>
      <Input id="name" bind:value={name} name="form[name]" class="w-full" />
    </div>

    <div>
      <h2 class="text-lg font-medium mb-2">Fields</h2>
      <div class="flex flex-col space-y-4">
        {#each fields as field, i (i)}
          <div class="flex flex-col sm:flex-row sm:items-center gap-3">
            <div class="flex-1">
              <Input
                bind:value={field.label}
                name={`form[structure][fields][${i}][label]`}
                placeholder="Label"
                oninput={(e:any)=>updateField(i, 'label', (e.target as HTMLInputElement).value)}
                class="w-full"
              />
            </div>

            <div class="w-40 flex-shrink-0">
              <BasicDropdown
                value={field.field_type}
                items={[{ value: 'text', label: 'Text' }, { value: 'number', label: 'Number' }, { value: 'date', label: 'Date' }]}
                on:select={(e:any) => updateField(i, 'field_type', e.detail.value)}
              />
              <input type="hidden" name={`form[structure][fields][${i}][field_type]`} value={field.field_type} />
            </div>

            <div class="flex items-center gap-2">
              <label class="flex items-center gap-2">
                <input
                  type="checkbox"
                  name={`form[structure][fields][${i}][required]`}
                  checked={field.required}
                  onchange={(e)=>updateField(i, 'required', (e.target as HTMLInputElement).checked)}
                />
                <span>Required</span>
              </label>
            </div>

            <div class="flex-shrink-0">
              <Button class="destructive" type="button" onclick={()=>removeField(i)}>Remove</Button>
            </div>
          </div>
        {/each}
      </div>

      <div class="mt-3">
        <Button class="outline" type="button" onclick={addField}>Add field</Button>
      </div>
    </div>

    <div class="mt-4 flex gap-2">
      <Button type="submit">Save</Button>
      <Button type="button" variant="outline" onclick={cancel}>Cancel</Button>
    </div>
  </Form>
</section>
