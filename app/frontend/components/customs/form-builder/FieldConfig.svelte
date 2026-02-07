<script lang="ts">
  // FieldConfig.svelte
  // Configuration panel for a single field.
  // Responsibilities:
  // - Edit label, required flag
  // - For select/radio: edit options
  // - For file: set allowed types and max size
  // - For table: edit columns
  // Emits `update` with a partial FormField patch when saved/changed.

  import type { FormField } from "./types";
  const { fields = [], index = 0, update }: { fields?: FormField[]; index?: number; update?: (patch: Partial<FormField>) => void } = $props();
  const field = $derived(fields[index] || { label: '', field_type: 'text', required: false, metadata: {} });

  function emitUpdate(patch: Partial<FormField>) {
    if (typeof update === 'function') update(patch);
  }
</script>

<div class="p-4 border-l">
  <h3 class="font-semibold mb-2">Field configuration</h3>
  <div class="mb-2">
    <label class="block text-sm" for="field-label">Label</label>
    <input id="field-label" class="w-full" value={field.label} oninput={(e:any)=>emitUpdate({ label: e.target.value })} />
  </div>
  <div class="mb-2">
    <label class="inline-flex items-center gap-2">
      <input type="checkbox" checked={field.required} onchange={(e:any)=>emitUpdate({ required: e.target.checked })} />
      <span>Required</span>
    </label>
  </div>

  <!-- Additional configuration UI (options, validations, file constraints, table columns) to be added here. -->

</div>

<!-- NOTE: For complex metadata (options, validation rules, table columns) create specialized inputs and emit structured patches.
-->
