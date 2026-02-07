<script lang="ts">
  import Button from "@/components/ui/button/button.svelte";
  // Canvas.svelte
  // Shows the ordered list of fields currently on the form.
  // Responsibilities:
  // - Render `fields` in order
  // - Provide actions: select, remove, duplicate, moveUp/moveDown (click-based for now)
  // - Placeholder hooks for drop targets (DND integration point)

  import type { FormField } from "./types";

  const { fields = [], select, remove, duplicate, moveUp, moveDown }: { fields?: FormField[]; select?: (i:number)=>void; remove?: (i:number)=>void; duplicate?: (i:number)=>void; moveUp?: (i:number)=>void; moveDown?: (i:number)=>void } = $props();

  function selectIndex(index:number) { if (typeof select === 'function') select(index); }
  function removeIndex(index:number) { if (typeof remove === 'function') remove(index); }
  function duplicateIndex(index:number) { if (typeof duplicate === 'function') duplicate(index); }
  function moveUpIndex(index:number) { if (typeof moveUp === 'function') moveUp(index); }
  function moveDownIndex(index:number) { if (typeof moveDown === 'function') moveDown(index); }
</script>

<style>
  .field-row { padding: 8px; border: 1px solid #e5e7eb; border-radius: 6px; margin-bottom: 8px; display:flex; justify-content:space-between; align-items:center }
  .controls { display:flex; gap:6px }
</style>

<div class="p-4">
  {#if fields.length === 0}
    <div class="text-sm text-muted-foreground">No fields yet. Use the palette to add fields.</div>
  {/if}

  {#each fields as field, i}
    <div class="field-row">
      <div>
        <div class="font-medium">{field.label || 'Untitled'}</div>
        <div class="text-xs text-muted-foreground">{field.field_type} • position {field.position}</div>
      </div>
      <div class="controls">
        <Button onclick={() => selectIndex(i)}>Edit</Button>
        <Button onclick={() => duplicateIndex(i)}>Duplicate</Button>
        <Button onclick={() => removeIndex(i)}>Delete</Button>
        <Button onclick={() => moveUpIndex(i)}>↑</Button>
        <Button onclick={() => moveDownIndex(i)}>↓</Button>
      </div>
    </div>
  {/each}
</div>

<!-- NOTE:
  - Replace the dispatchEvent usages with Svelte component events (createEventDispatcher)
    if you prefer the canonical Svelte pattern. Using `dispatchEvent` keeps this scaffold minimal.
  - When integrating DnD, wrap each field-row with the drop target and update ordering accordingly.
-->
