<script lang="ts">
  import Palette from "./form-builder/Palette.svelte";
  import Canvas from "./form-builder/Canvas.svelte";
  import FieldConfig from "./form-builder/FieldConfig.svelte";
  import FormSettingsPanel from "./form-builder/FormSettings.svelte";
  import FormMappingPanel from "./form-builder/FormMapping.svelte";
  import { createField, duplicateExportKeys, type FormField, type FieldType, type FormSettings } from "./form-builder/types";
  import type { DropResult } from "@/lib/dnd";

  interface Props {
    fields: FormField[];
    settings?: FormSettings;
    showMappingWarning?: boolean;
    onmappingvaliditychange?: (isValid: boolean) => void;
  }

  let {
    fields = $bindable([]),
    settings = $bindable({}),
    showMappingWarning = false,
    onmappingvaliditychange,
  }: Props = $props();

  let selectedIndex = $state<number | null>(null);
  let rightPanelView = $state<'field' | 'settings' | 'mapping'>('field');

  function addField(fieldType: FieldType) {
    const newField = createField(fieldType, fields.length + 1);
    fields = [...fields, newField];
    selectedIndex = fields.length - 1;
  }

  function removeField(index: number) {
    fields = fields
      .filter((_: FormField, i: number) => i !== index)
      .map((f: FormField, i: number) => ({ ...f, position: i + 1 }));
    if (selectedIndex === index) selectedIndex = null;
    else if (selectedIndex !== null && selectedIndex > index) selectedIndex--;
  }

  function duplicateField(index: number) {
    const src = fields[index];
    if (!src) return;
    const copy: FormField = {
      ...src,
      id: undefined,
      label: src.label + ' (copy)',
      metadata: { ...src.metadata },
      position: 0,
    };
    fields = [
      ...fields.slice(0, index + 1),
      copy,
      ...fields.slice(index + 1),
    ].map((f, i) => ({ ...f, position: i + 1 }));
    selectedIndex = index + 1;
  }

  function moveUp(index: number) {
    if (index <= 0) return;
    const a = fields.slice();
    [a[index - 1], a[index]] = [a[index], a[index - 1]];
    fields = a.map((f: FormField, i: number) => ({ ...f, position: i + 1 }));
    if (selectedIndex === index) selectedIndex = index - 1;
    else if (selectedIndex === index - 1) selectedIndex = index;
  }

  function moveDown(index: number) {
    if (index >= fields.length - 1) return;
    const a = fields.slice();
    [a[index], a[index + 1]] = [a[index + 1], a[index]];
    fields = a.map((f: FormField, i: number) => ({ ...f, position: i + 1 }));
    if (selectedIndex === index) selectedIndex = index + 1;
    else if (selectedIndex === index + 1) selectedIndex = index;
  }

  function updateField(index: number, patch: Partial<FormField>) {
    const next = fields.slice();
    next[index] = { ...next[index], ...patch };
    fields = next;
  }

  function handleDrop(result: DropResult) {
    const { data, index } = result;

    if (data.kind === 'palette' && data.fieldType) {
      const newField = createField(data.fieldType as FieldType, 0);
      fields = [
        ...fields.slice(0, index),
        newField,
        ...fields.slice(index),
      ].map((f, i) => ({ ...f, position: i + 1 }));
      selectedIndex = index;
      return;
    }

    if (data.kind === 'canvas' && data.fieldIndex !== undefined) {
      const from = data.fieldIndex;
      let to = index;
      if (to === from || to === from + 1) return;
      if (to > from) to -= 1;
      const arr = fields.slice();
      const [moved] = arr.splice(from, 1);
      arr.splice(to, 0, moved);
      fields = arr.map((f, i) => ({ ...f, position: i + 1 }));
      selectedIndex = to;
    }
  }

  const selectedField = $derived(
    selectedIndex !== null && selectedIndex < fields.length
      ? fields[selectedIndex]
      : null
  );

  const duplicateMappingKeys = $derived(duplicateExportKeys(fields));
  const hasMappingDuplicates = $derived(duplicateMappingKeys.length > 0);

  $effect(() => {
    onmappingvaliditychange?.(!hasMappingDuplicates);
  });

  $effect(() => {
    if (showMappingWarning && hasMappingDuplicates) {
      rightPanelView = 'mapping';
    }
  });
</script>

<div class="grid gap-4 lg:grid-cols-[240px_1fr_280px] w-full">
  <div class="block lg:block">
    <Palette add={addField} />
  </div>

  <div>
    <Canvas
      {fields}
      {selectedIndex}
      onselect={(i) => (selectedIndex = i)}
      onremove={removeField}
      onduplicate={duplicateField}
      onmoveup={moveUp}
      onmovedown={moveDown}
      ondrop={handleDrop}
    />
  </div>

  <div class="block lg:block">
    <div class="mb-3 flex rounded-lg border bg-muted p-1">
      <button
        type="button"
        class="flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition-colors {rightPanelView === 'field' ? 'bg-background shadow-sm' : 'text-muted-foreground hover:text-foreground'}"
        onclick={() => rightPanelView = 'field'}
      >
        Field
      </button>
      <button
        type="button"
        class="flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition-colors {rightPanelView === 'settings' ? 'bg-background shadow-sm' : 'text-muted-foreground hover:text-foreground'}"
        onclick={() => rightPanelView = 'settings'}
      >
        Styling
      </button>
      <button
        type="button"
        class="flex-1 rounded-md border px-3 py-1.5 text-sm font-medium transition-colors {rightPanelView === 'mapping' ? 'bg-background shadow-sm border-border' : 'border-transparent text-muted-foreground hover:text-foreground'} {showMappingWarning && hasMappingDuplicates ? 'border-destructive text-destructive ring-1 ring-destructive/30' : ''}"
        onclick={() => rightPanelView = 'mapping'}
      >
        Mapping
      </button>
    </div>

    {#if rightPanelView === 'settings'}
      <FormSettingsPanel
        {settings}
        onupdate={(s) => settings = s}
      />
    {:else if rightPanelView === 'mapping'}
      <FormMappingPanel
        {fields}
        onupdate={updateField}
        showValidation={showMappingWarning}
        duplicateKeys={duplicateMappingKeys}
      />
    {:else if selectedField && selectedIndex !== null}
      <FieldConfig
        field={selectedField}
        onupdate={(patch) => updateField(selectedIndex as number, patch)}
      />
    {:else}
      <aside class="rounded-lg border bg-card">
        <div class="flex flex-col items-center justify-center gap-2 px-4 py-12 text-center">
          <p class="text-sm font-medium text-muted-foreground">No field selected</p>
          <p class="text-xs text-muted-foreground">Click a field in the canvas to configure it.</p>
        </div>
      </aside>
    {/if}
  </div>
</div>
