<script lang="ts">
  import { FIELD_CATEGORIES, FIELD_TYPE_LABELS, type FieldType } from "./types";
  import {
    Type,
    Hash,
    Mail,
    AlignLeft,
    List,
    CircleDot,
    SquareCheck,
    Calendar,
    Upload,
    Table,
    MousePointerClick,
    LayoutList,
    Heading2,
    FileText,
    Minus,
    Image,
  } from "@lucide/svelte";
  import { draggable } from "@/lib/dnd";

  const { add }: { add?: (type: FieldType) => void } = $props();

  const iconMap: Record<FieldType, typeof Type> = {
    text: Type,
    number: Hash,
    email: Mail,
    textarea: AlignLeft,
    select: List,
    radio: CircleDot,
    checkbox: SquareCheck,
    date: Calendar,
    file: Upload,
    table: Table,
    button: MousePointerClick,
    buttons: MousePointerClick,
    section: LayoutList,
    subtitle: Heading2,
    static_text: FileText,
    separator: Minus,
    logo: Image,
  };

  function handleAdd(type: FieldType) {
    if (typeof add === 'function') add(type);
  }
</script>

<aside class="rounded-lg border bg-card p-3 sm:p-4 w-full max-w-full box-border">
  <h3 class="mb-3 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
    Field Types
  </h3>
  {#each FIELD_CATEGORIES as category}
    <div class="mb-4 last:mb-0">
      <p class="mb-2 text-xs font-medium text-muted-foreground">{category.name}</p>
      <div class="grid grid-cols-2 gap-1 sm:gap-1.5">
        {#each category.types as fieldType}
          {@const Icon = iconMap[fieldType]}
          <button
            type="button"
            class="flex items-center gap-2 rounded-md border border-transparent px-2 py-1.5 sm:px-2.5 sm:py-2 text-left text-xs sm:text-sm transition-colors hover:border-border hover:bg-accent"
            onclick={() => handleAdd(fieldType)}
            use:draggable={{
              data: () => ({
                kind: 'palette' as const,
                fieldType,
                label: FIELD_TYPE_LABELS[fieldType],
                badge: fieldType,
              }),
            }}
          >
            <Icon class="size-4 shrink-0 text-muted-foreground" />
            <span>{FIELD_TYPE_LABELS[fieldType]}</span>
          </button>
        {/each}
      </div>
    </div>
  {/each}
</aside>
