<script lang="ts">
  // Preview.svelte
  // Simple preview renderer used by the builder to show how the form will look.
  // For now this is read-only and demonstrates labels and input placeholders.
  import type { FormField } from "./types";
  import ButtonsField from './ButtonsField.svelte';
  const { fields = [] }: { fields?: FormField[] } = $props();
</script>

<div class="p-4 mt-4 border-t">
  <h3 class="font-semibold mb-2">Preview</h3>
  <form>
    {#each fields as f}
      {@const fid = `field_${f.id ?? f.position}`}
      <div class="mb-3">
        <label class="block font-medium mb-1" for={fid}>{f.label}</label>
        {#if f.field_type === 'textarea'}
          <textarea id={f.label} class="w-full p-2 border rounded" placeholder={f.label}></textarea>
        {:else if f.field_type === 'select'}
          <select id={f.label} class="w-full p-2 border rounded"><option>Option</option></select>
        {:else if f.field_type === 'buttons'}
          <ButtonsField
            options={(f.metadata.options || []).map((o) => ({ label: o, value: o }))}
            multiple={f.metadata.allow_multiple}
            name={fid}
            onChange={() => {}}
            onValue={() => {}}
            value={f.metadata.allow_multiple ? [] : null}
          />
        {:else}
          <input id={fid} name={fid} class="w-full p-2 border rounded" placeholder={f.label} />
        {/if}
      </div>
    {/each}
  </form>
</div>

<!-- NOTE: This preview is simple; reuse `FormFieldRenderer` from the app when you want behavior parity with the live form.
-->
