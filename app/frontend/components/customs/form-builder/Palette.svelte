<script lang="ts">
  // Palette.svelte
  // Displays categorized field types (Basic, Table, Buttons)
  // Current behavior: click a field type to add to the canvas (emits `add` with field_type string)
  // Future: make each item a DnD drag source.

  import Button from "@/components/ui/button/button.svelte";

  const { add }: { add?: (type: string) => void } = $props();
  // should move in a shared file later
  const categories = [
    { name: 'Basic', items: ['text','number','email','date','textarea','checkbox','select','radio','file'] },
    { name: 'Table', items: ['table'] },
    { name: 'Buttons', items: ['submit','reset'] }
  ];

  function emitAdd(type: string) {
    // Call the callback prop passed from parent (Svelte 5 pattern)
    if (typeof add === 'function') add(type);
  }
</script>

<style>
  .category { margin-bottom: 12px; }
  .item { padding: 8px; border-radius: 6px; cursor: pointer; background: var(--muted); margin-bottom:6px }
</style>

<div class="p-4">
  {#each categories as cat}
    <div class="category">
      <h3 class="text-sm font-semibold mb-2">{cat.name}</h3>
      <div>
        {#each cat.items as it}
          <Button class="item" role="button" onclick={() => emitAdd(it)}>
            {it}
          </Button>
        {/each}
      </div>
    </div>
  {/each}
</div>

<!-- NOTE:
  - This file uses a simple click-to-add mechanism for now. When integrating a DnD library,
    convert each `.item` into a drag source and expose necessary data/drag handles.
  - Consider adding accessible labels and descriptions for screen readers (WCAG).
-->
