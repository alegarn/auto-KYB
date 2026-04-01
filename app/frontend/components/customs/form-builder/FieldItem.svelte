<script lang="ts">
  import { FIELD_TYPE_LABELS, isLayoutField, type FormField } from "./types";
  import { Pencil, Copy, Trash2, ChevronUp, ChevronDown, GripVertical } from "@lucide/svelte";
  import { draggable } from "@/lib/dnd";

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

  const isLayout = $derived(isLayoutField(field.field_type));
</script>

<div
  class="group flex w-full max-w-full flex-wrap items-start gap-2 rounded-lg border px-2 py-2 box-border transition-colors sm:px-3 sm:py-2.5 {isSelected ? 'border-primary bg-primary/5 ring-1 ring-primary/20' : 'border-border bg-card hover:border-primary/30'}"
  data-dnd-item
  role="listitem"
  use:draggable={{
    data: () => ({
      kind: 'canvas' as const,
      fieldIndex: index,
      label: field.label || 'Untitled',
      badge: field.field_type,
    }),
    handle: '[data-drag-handle]',
  }}
>
  <div class="cursor-grab text-muted-foreground/40" data-drag-handle aria-hidden="true">
    <GripVertical class="size-4" />
  </div>

  <button
    type="button"
    class="flex min-w-0 flex-1 items-start gap-2 text-left sm:gap-3"
    onclick={() => onselect?.(index)}
  >
    <div class="min-w-0 flex-1">
      <p class="line-clamp-2 break-words text-sm font-medium leading-5 sm:text-sm">{field.label || 'Untitled'}</p>
      <p class="mt-0.5 text-[11px] text-muted-foreground sm:text-xs">
        {FIELD_TYPE_LABELS[field.field_type] || field.field_type}
        {#if !isLayout && field.required}
          <span class="ml-1 text-destructive">*</span>
        {/if}
      </p>
    </div>
    <span class="shrink-0 self-start whitespace-nowrap rounded-full px-2 py-0.5 text-center text-[9px] font-medium uppercase sm:text-[10px] {isLayout ? 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' : 'bg-muted text-muted-foreground'}">
      {field.field_type}
    </span>
  </button>

  <div
    class="flex basis-full justify-end gap-0.5 pl-6 opacity-0 transition-opacity group-hover:opacity-100 sm:basis-auto sm:items-center sm:pl-0"
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
