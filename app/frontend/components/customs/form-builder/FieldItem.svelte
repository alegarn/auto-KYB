<script lang="ts">
  import { FIELD_TYPE_LABELS, type FormField } from "./types";
  import { Pencil, Copy, Trash2, ChevronUp, ChevronDown, GripVertical } from "@lucide/svelte";

  interface Props {
    field: FormField;
    index: number;
    isSelected?: boolean;
    isFirst?: boolean;
    isLast?: boolean;
    onselect?: (i: number) => void;
    onremove?: (i: number) => void;
    onduplicate?: (i: number) => void;
    onmoveup?: (i: number) => void;
    onmovedown?: (i: number) => void;
  }

  const {
    field,
    index,
    isSelected = false,
    isFirst = false,
    isLast = false,
    onselect,
    onremove,
    onduplicate,
    onmoveup,
    onmovedown,
  }: Props = $props();
</script>

<div
  class="group flex items-center gap-2 rounded-lg border px-3 py-2.5 transition-colors {isSelected ? 'border-primary bg-primary/5 ring-1 ring-primary/20' : 'border-border bg-card hover:border-primary/30'}"
  data-droppable="canvas-item"
  data-index={index}
  role="listitem"
>
  <div class="cursor-grab text-muted-foreground/40" data-drag-handle aria-hidden="true">
    <GripVertical class="size-4" />
  </div>

  <button
    type="button"
    class="flex min-w-0 flex-1 items-center gap-3 text-left"
    onclick={() => onselect?.(index)}
  >
    <div class="min-w-0 flex-1">
      <p class="truncate text-sm font-medium">{field.label || 'Untitled'}</p>
      <p class="text-xs text-muted-foreground">
        {FIELD_TYPE_LABELS[field.field_type] || field.field_type}
        {#if field.required}
          <span class="ml-1 text-destructive">*</span>
        {/if}
      </p>
    </div>
    <span class="shrink-0 rounded-full bg-muted px-2 py-0.5 text-[10px] font-medium uppercase text-muted-foreground">
      {field.field_type}
    </span>
  </button>

  <div
    class="flex shrink-0 items-center gap-0.5 opacity-0 transition-opacity group-hover:opacity-100"
    class:opacity-100={isSelected}
  >
    <button type="button" class="rounded p-1 text-muted-foreground hover:bg-accent hover:text-foreground disabled:pointer-events-none disabled:opacity-30" onclick={() => onmoveup?.(index)} disabled={isFirst} aria-label="Move up">
      <ChevronUp class="size-3.5" />
    </button>
    <button type="button" class="rounded p-1 text-muted-foreground hover:bg-accent hover:text-foreground disabled:pointer-events-none disabled:opacity-30" onclick={() => onmovedown?.(index)} disabled={isLast} aria-label="Move down">
      <ChevronDown class="size-3.5" />
    </button>
    <button type="button" class="rounded p-1 text-muted-foreground hover:bg-accent hover:text-foreground" onclick={() => onselect?.(index)} aria-label="Edit">
      <Pencil class="size-3.5" />
    </button>
    <button type="button" class="rounded p-1 text-muted-foreground hover:bg-accent hover:text-foreground" onclick={() => onduplicate?.(index)} aria-label="Duplicate">
      <Copy class="size-3.5" />
    </button>
    <button type="button" class="rounded p-1 text-muted-foreground hover:bg-destructive/10 hover:text-destructive" onclick={() => onremove?.(index)} aria-label="Delete">
      <Trash2 class="size-3.5" />
    </button>
  </div>
</div>
