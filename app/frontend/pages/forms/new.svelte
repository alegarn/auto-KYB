<script lang="ts">
  import { Form } from '@inertiajs/svelte'
  import { Button } from "/components/ui/button/index.js"
  import { Input } from "/components/ui/input/index.js"
  import { Checkbox } from "/components/ui/checkbox/index.js"
  import { Label } from "/components/ui/label/index.js"
  import DropdownMenu from '/components/ui/dropdown-menu/dropdown-menu.svelte'
  import DropdownMenuTrigger from '/components/ui/dropdown-menu/dropdown-menu-trigger.svelte'
  import DropdownMenuRadioGroup from '/components/ui/dropdown-menu/dropdown-menu-radio-group.svelte'
  import DropdownMenuGroup from '@/components/ui/dropdown-menu/dropdown-menu-group.svelte';
  import DropdownMenuRadioItem from '@/components/ui/dropdown-menu/dropdown-menu-radio-item.svelte';
  import DropdownMenuContent from '@/components/ui/dropdown-menu/dropdown-menu-content.svelte';
  
  let name = $state("")
  let fields = $state<Array<{ label: string; field_type: string; required: boolean }>>([])
  let position = $state("bottom");

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

  function cancel() {
    history.back()
  }
</script>

<section class="p-6">
  <h1>Create Form</h1>
  <Form action="/forms" method="post">
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
                oninput={(e: any) => updateField(i, 'label', (e.target as HTMLInputElement).value)}
              />
              <div class="relative">
                <DropdownMenu>
                  <DropdownMenuTrigger>
                    {#snippet child({props})}
                      <Button {...props} variant="outline">{field.field_type}</Button>
                    {/snippet}
                  </DropdownMenuTrigger>
                  <DropdownMenuContent>
                    <DropdownMenuGroup>
                    <DropdownMenuRadioGroup bind:value={position}>
                      <DropdownMenuRadioItem value="text" onclick={() => updateField(i, 'field_type', 'text')}>Text</DropdownMenuRadioItem>
                      <DropdownMenuRadioItem value="number" onclick={() => updateField(i, 'field_type', 'number')}>Number</DropdownMenuRadioItem>
                      <DropdownMenuRadioItem value="date" onclick={() => updateField(i, 'field_type', 'date')}>Date</DropdownMenuRadioItem>
                    </DropdownMenuRadioGroup>
                    </DropdownMenuGroup>
                  </DropdownMenuContent>
                </DropdownMenu>
                <input type="hidden" name={`form[structure][fields][${i}][field_type]`} value={field.field_type} />
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
