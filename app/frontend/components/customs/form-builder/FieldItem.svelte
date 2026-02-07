<script lang="ts">
  // FieldItem.svelte
  // Small presentational component used by the Canvas to render a single field.
  // This file is a placeholder; it should encapsulate the field preview (label, required marker)
  // and expose local actions when needed.

  import type { FormField } from "./types";
  const { field = { label: '', field_type: 'text', required: false, metadata: {} } }: { field?: FormField } = $props();
</script>

<div class="p-2 border rounded">
  <div class="font-medium">{field.label}</div>
  <div class="text-xs text-muted-foreground">{field.field_type} {field.required ? '• required' : ''}</div>
</div>

<!-- NOTE: turn this into a draggable item for DnD later; expose drag handles and data attributes. -->
