<script lang="ts">
  // Preview.svelte
  // Simple preview renderer used by the builder to show how the form will look.
  // For now this is read-only and demonstrates labels and input placeholders.
  import type { FormField } from "./types";
  import { ALLOWED_FILE_EXTENSIONS } from "./types";
  import ButtonsField from './ButtonsField.svelte';
  const { fields = [] }: { fields?: FormField[] } = $props();

  // build accept string from a field's allowed types (keeps logic out of template)
  function acceptForFile(f: FormField): string {
    const types = (f.metadata.file?.allowed_types && f.metadata.file.allowed_types.length)
      ? f.metadata.file.allowed_types
      : ALLOWED_FILE_EXTENSIONS;
    return types.map(t => t.startsWith('.') ? t : `.${t.replace(/^\./, '')}`).join(',');
  }

  function allowedTypesLabel(f: FormField): string {
    const types = (f.metadata.file?.allowed_types && f.metadata.file.allowed_types.length)
      ? f.metadata.file.allowed_types
      : ALLOWED_FILE_EXTENSIONS;
    return types.map(t => t.replace(/^\./, '').toUpperCase()).join(', ');
  }
</script>

<div class="p-4 mt-4 border-t">
  <h3 class="font-semibold mb-2">Preview</h3>
  <form>
    {#each fields as f}
      {@const fid = `field_${f.id ?? f.position}`}
      <div class="mb-3">
        <label class="block font-medium mb-1" for={fid}>{f.label}</label>
        {#if f.field_type === 'textarea'}
          <textarea id={fid} name={fid} class="w-full p-2 border rounded" placeholder={f.label}></textarea>
        {:else if f.field_type === 'select'}
          <select id={fid} name={fid} class="w-full p-2 border rounded"><option>Option</option></select>
        {:else if f.field_type === 'buttons'}
          <ButtonsField
            options={(f.metadata.options || []).map((o) => ({ label: o, value: o }))}
            multiple={f.metadata.allow_multiple}
            name={fid}
            onChange={() => {}}
            onValue={() => {}}
            value={f.metadata.allow_multiple ? [] : null}
          />
        {:else if f.field_type === 'file'}
          <input id={fid} name={fid} type="file" accept={acceptForFile(f)} class="w-full p-2 border rounded" />
          <p class="mt-1 text-xs text-muted-foreground">Supported types: {allowedTypesLabel(f)}</p>
        {:else}
          <input id={fid} name={fid} class="w-full p-2 border rounded" placeholder={f.label} />
        {/if}
      </div>
    {/each}
  </form>
</div>

<!-- NOTE: This preview is simple; reuse `FormFieldRenderer` from the app when you want behavior parity with the live form.
-->
