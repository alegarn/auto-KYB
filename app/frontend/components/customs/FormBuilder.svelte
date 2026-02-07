<script lang="ts">
  // FormBuilder.svelte
  // Shell component that orchestrates the form builder UI.
  // Responsibilities:
  // - Render the `Palette`, `Canvas`, and `FieldConfig` areas
  // - Maintain the `fields` array shape and expose it to the parent
  // - Provide click-to-add and move up/down operations now
  // - Provide placeholders/hooks to attach a DnD library later
  
  import Palette from "./form-builder/Palette.svelte";
  import Canvas from "./form-builder/Canvas.svelte";
  import FieldConfig from "./form-builder/FieldConfig.svelte";
  import Preview from "./form-builder/Preview.svelte";
  import type { FormField } from "./form-builder/types";

  interface Props {
    initialFields?: FormField[] | undefined;
    fields?: FormField[];
  }

  const { initialFields = undefined } = $props();
  let fields = $derived(initialFields || [])

  // Selected field for configuring (index in the fields array)
  let selectedIndex = $state<number | null>(null);

  // Click-to-add API used by the Palette now; later the Palette will provide drag sources
  function addField(fieldType: string) {
    const next: FormField = { label: 'New field', field_type: fieldType as any, required: false, position: fields.length + 1, metadata: {} };
    fields = [...fields, next];
  }

  function removeField(index: number) {
    fields = fields.filter((_: FormField, i: number) => i !== index).map((f: FormField, i: number) => ({ ...f, position: i + 1 }));
    if (selectedIndex === index) selectedIndex = null;
  }

  function duplicateField(index: number) {
    const copy = { ...(fields[index] || {}), label: (fields[index]?.label || 'Copy') + ' (copy)', position: fields.length + 1 };
    fields = [...fields.slice(0, index + 1), copy, ...fields.slice(index + 1)].map((f, i) => ({ ...f, position: i + 1 }));
  }

  function moveUp(index: number) {
    if (index <= 0) return;
    const a = fields.slice();
    [a[index - 1], a[index]] = [a[index], a[index - 1]];
    fields = a.map((f: FormField, i: number) => ({ ...f, position: i + 1 }));
  }

  function moveDown(index: number) {
    if (index >= fields.length - 1) return;
    const a = fields.slice();
    [a[index], a[index + 1]] = [a[index + 1], a[index]];
    fields = a.map((f: FormField, i: number) => ({ ...f, position: i + 1 }));
  }

  // Called by FieldConfig when updates are made
  function updateField(index: number, patch: Partial<FormField>) {
    const next = fields.slice();
    next[index] = { ...next[index], ...patch };
    fields = next;
  }

  // Placeholder method for future DnD integration
  function handleDropPlaceholder() {
    // When DnD library is integrated, update `fields` order here
  }
</script>

<style>
  /* Basic layout styles can be extended to match app theme. */
  .builder { display: grid; grid-template-columns: 320px 1fr 360px; gap: 16px; }
  @media (max-width: 767px) { .builder { grid-template-columns: 1fr; } }
</style>

<!-- Layout: Palette | Canvas | Config -->
<div class="builder">
  <div>
    <Palette add={(type:any) => addField(type)} />
  </div>

  <div>
    <Canvas {fields}
      select={(index:any) => (selectedIndex = index)}
      remove={(index:any) => removeField(index)}
      duplicate={(index:any) => duplicateField(index)}
      moveUp={(index:any) => moveUp(index)}
      moveDown={(index:any) => moveDown(index)}
      />
    <!-- Preview toggle could be added here -->
    <Preview {fields} />
  </div>

  <div>
    {#if selectedIndex !== null}
      <FieldConfig {fields} index={selectedIndex} update={(patch:any)=>updateField(selectedIndex as number, patch)} />
    {:else}
      <div class="p-4 text-sm text-muted-foreground">Select a field to edit its properties</div>
    {/if}
  </div>
</div>

<!-- Integration notes:
  - In app/frontend/pages/forms/new.svelte and edit.svelte replace manual fields UI with
      <FormBuilder bind:fields={fields} initialFields={initialFields} />
  - On form submit, ensure hidden inputs are generated for `form[structure][fields]` to match server shape.
  - Later: attach a DnD library in `Canvas` and call `handleDropPlaceholder` to persist order changes.
-->
