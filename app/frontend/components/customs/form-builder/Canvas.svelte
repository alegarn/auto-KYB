<script lang="ts">
  import FieldItem from "./FieldItem.svelte";
  import type { FormField } from "./types";
  import { LayoutList } from "@lucide/svelte";
  import { dropZone, type DropResult } from "@/lib/dnd";

  interface Props {
    fields?: FormField[];
    selectedIndex?: number | null;
    onselect?: (i: number) => void;
    onremove?: (i: number) => void;
    onduplicate?: (i: number) => void;
    onmoveup?: (i: number) => void;
    onmovedown?: (i: number) => void;
    ondrop?: (result: DropResult) => void;
  }

  const {
    fields = [],
    selectedIndex = null,
    onselect,
    onremove,
    onduplicate,
    onmoveup,
    onmovedown,
    ondrop,
  }: Props = $props();
</script>

<div
  class="rounded-lg border bg-card"
  role="list"
  aria-label="Form fields"
  use:dropZone={{ onDrop: (r) => ondrop?.(r) }}
>
  {#if fields.length === 0}
    <div class="flex flex-col items-center justify-center gap-3 px-6 py-16 text-center" data-dnd-items>
      <div class="rounded-full bg-muted p-3">
        <LayoutList class="size-6 text-muted-foreground" />
      </div>
      <div>
        <p class="text-sm font-medium">No fields yet</p>
        <p class="mt-1 text-xs text-muted-foreground">Click or drag a field type from the palette to add it here.</p>
      </div>
    </div>
  {:else}
    <div class="space-y-1.5 p-3" data-dnd-items>
      {#each fields as field, i (field.id ?? `pos-${i}`)}
        <FieldItem
          {field}
          index={i}
          isSelected={selectedIndex === i}
          isFirst={i === 0}
          isLast={i === fields.length - 1}
          {onselect}
          {onremove}
          {onduplicate}
          {onmoveup}
          {onmovedown}
        />
      {/each}
    </div>
    <div class="border-t px-3 py-2 text-xs text-muted-foreground">
      {fields.length} field{fields.length === 1 ? '' : 's'}
    </div>
  {/if}
</div>
