<script lang="ts">
  import { FIELD_TYPE_LABELS, type FormField, type FieldMetadata } from "./types";
  import { Input } from "@/components/ui/input/index.js";
  import { Label } from "@/components/ui/label/index.js";
  import { Separator } from "@/components/ui/separator/index.js";
  import { X, Plus } from "@lucide/svelte";

  interface Props {
    field: FormField;
    onupdate?: (patch: Partial<FormField>) => void;
  }

  const { field, onupdate }: Props = $props();

  function emit(patch: Partial<FormField>) {
    onupdate?.(patch);
  }

  function emitMeta(key: keyof FieldMetadata, value: any) {
    emit({ metadata: { ...field.metadata, [key]: value } });
  }

  function updateOption(idx: number, value: string) {
    const opts = [...(field.metadata.options || [])];
    opts[idx] = value;
    emitMeta('options', opts);
  }

  function addOption() {
    emitMeta('options', [...(field.metadata.options || []), `Option ${(field.metadata.options?.length || 0) + 1}`]);
  }

  function removeOption(idx: number) {
    const opts = (field.metadata.options || []).filter((_: string, i: number) => i !== idx);
    emitMeta('options', opts);
  }

  function updateColumn(idx: number, key: string, value: string) {
    const cols = [...(field.metadata.columns || [])];
    cols[idx] = { ...cols[idx], [key]: value };
    emitMeta('columns', cols);
  }

  function addColumn() {
    const cols = field.metadata.columns || [];
    emitMeta('columns', [...cols, { key: `col_${cols.length + 1}`, label: `Column ${cols.length + 1}`, type: 'text' }]);
  }

  function removeColumn(idx: number) {
    emitMeta('columns', (field.metadata.columns || []).filter((_: any, i: number) => i !== idx));
  }

  const hasOptions = $derived(
    field.field_type === 'select' || field.field_type === 'radio' || field.field_type === 'checkbox'
  );
  const hasTextValidation = $derived(
    field.field_type === 'text' || field.field_type === 'email' || field.field_type === 'textarea'
  );
  const hasNumberValidation = $derived(field.field_type === 'number');
  const hasPlaceholder = $derived(
    ['text', 'number', 'email', 'textarea'].includes(field.field_type)
  );
</script>

<aside class="rounded-lg border bg-card">
  <div class="border-b px-4 py-3">
    <h3 class="text-sm font-semibold">Field Settings</h3>
    <p class="text-xs text-muted-foreground">{FIELD_TYPE_LABELS[field.field_type]}</p>
  </div>

  <div class="space-y-4 p-4">
    <div>
      <Label for="cfg-label" class="mb-1.5 block text-xs font-medium">Label</Label>
      <Input
        id="cfg-label"
        value={field.label}
        oninput={(e: any) => emit({ label: e.target.value })}
        class="h-8 text-sm"
      />
    </div>

    {#if hasPlaceholder}
      <div>
        <Label for="cfg-placeholder" class="mb-1.5 block text-xs font-medium">Placeholder</Label>
        <Input
          id="cfg-placeholder"
          value={field.metadata.placeholder || ''}
          oninput={(e: any) => emitMeta('placeholder', e.target.value)}
          class="h-8 text-sm"
        />
      </div>
    {/if}

    <div>
      <Label for="cfg-desc" class="mb-1.5 block text-xs font-medium">Description</Label>
      <Input
        id="cfg-desc"
        value={field.metadata.description || ''}
        oninput={(e: any) => emitMeta('description', e.target.value)}
        class="h-8 text-sm"
      />
    </div>

    <label class="flex items-center gap-2">
      <input
        type="checkbox"
        checked={field.required}
        onchange={(e: any) => emit({ required: e.target.checked })}
        class="size-4 rounded border-border"
      />
      <span class="text-sm">Required</span>
    </label>

    {#if hasOptions}
      <Separator />
      <div>
        <div class="mb-2 flex items-center justify-between">
          <span class="text-xs font-medium">Options</span>
          <button type="button" class="flex items-center gap-1 rounded px-1.5 py-0.5 text-xs text-primary hover:bg-accent" onclick={addOption}>
            <Plus class="size-3" /> Add
          </button>
        </div>
        <div class="space-y-1.5">
          {#each field.metadata.options || [] as opt, i}
            <div class="flex items-center gap-1.5">
              <Input
                value={opt}
                oninput={(e: any) => updateOption(i, e.target.value)}
                class="h-7 flex-1 text-xs"
              />
              <button type="button" class="shrink-0 rounded p-0.5 text-muted-foreground hover:text-destructive" onclick={() => removeOption(i)} aria-label="Remove option">
                <X class="size-3.5" />
              </button>
            </div>
          {/each}
        </div>
        {#if field.field_type === 'checkbox'}
          <label class="mt-2 flex items-center gap-2">
            <input
              type="checkbox"
              checked={field.metadata.allow_multiple || false}
              onchange={(e: any) => emitMeta('allow_multiple', e.target.checked)}
              class="size-4 rounded border-border"
            />
            <span class="text-xs">Allow multiple selections</span>
          </label>
        {/if}
      </div>
    {/if}

    {#if hasTextValidation}
      <Separator />
      <div>
        <span class="mb-2 block text-xs font-medium">Validation</span>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <Label for="cfg-minlen" class="mb-1 block text-[11px] text-muted-foreground">Min length</Label>
            <Input
              id="cfg-minlen"
              type="number"
              value={field.metadata.validation?.min_length ?? ''}
              oninput={(e: any) => emitMeta('validation', { ...field.metadata.validation, min_length: e.target.value ? Number(e.target.value) : undefined })}
              class="h-7 text-xs"
            />
          </div>
          <div>
            <Label for="cfg-maxlen" class="mb-1 block text-[11px] text-muted-foreground">Max length</Label>
            <Input
              id="cfg-maxlen"
              type="number"
              value={field.metadata.validation?.max_length ?? ''}
              oninput={(e: any) => emitMeta('validation', { ...field.metadata.validation, max_length: e.target.value ? Number(e.target.value) : undefined })}
              class="h-7 text-xs"
            />
          </div>
        </div>
        <div class="mt-2">
          <Label for="cfg-pattern" class="mb-1 block text-[11px] text-muted-foreground">Pattern (regex)</Label>
          <Input
            id="cfg-pattern"
            value={field.metadata.validation?.pattern || ''}
            oninput={(e: any) => emitMeta('validation', { ...field.metadata.validation, pattern: e.target.value || undefined })}
            class="h-7 text-xs"
          />
        </div>
      </div>
    {/if}

    {#if hasNumberValidation}
      <Separator />
      <div>
        <span class="mb-2 block text-xs font-medium">Validation</span>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <Label for="cfg-min" class="mb-1 block text-[11px] text-muted-foreground">Min</Label>
            <Input
              id="cfg-min"
              type="number"
              value={field.metadata.validation?.min ?? ''}
              oninput={(e: any) => emitMeta('validation', { ...field.metadata.validation, min: e.target.value ? Number(e.target.value) : undefined })}
              class="h-7 text-xs"
            />
          </div>
          <div>
            <Label for="cfg-max" class="mb-1 block text-[11px] text-muted-foreground">Max</Label>
            <Input
              id="cfg-max"
              type="number"
              value={field.metadata.validation?.max ?? ''}
              oninput={(e: any) => emitMeta('validation', { ...field.metadata.validation, max: e.target.value ? Number(e.target.value) : undefined })}
              class="h-7 text-xs"
            />
          </div>
        </div>
      </div>
    {/if}

    {#if field.field_type === 'file'}
      <Separator />
      <div>
        <span class="mb-2 block text-xs font-medium">File Settings</span>
        <div>
          <Label for="cfg-maxsize" class="mb-1 block text-[11px] text-muted-foreground">Max size (KB)</Label>
          <Input
            id="cfg-maxsize"
            type="number"
            value={field.metadata.file?.max_size_kb ?? ''}
            oninput={(e: any) => emitMeta('file', { ...field.metadata.file, max_size_kb: e.target.value ? Number(e.target.value) : undefined })}
            class="h-7 text-xs"
          />
        </div>
        <div class="mt-2">
          <Label for="cfg-filetypes" class="mb-1 block text-[11px] text-muted-foreground">Allowed types (comma-separated)</Label>
          <Input
            id="cfg-filetypes"
            value={(field.metadata.file?.allowed_types || []).join(', ')}
            oninput={(e: any) => emitMeta('file', { ...field.metadata.file, allowed_types: e.target.value.split(',').map((s: string) => s.trim()).filter(Boolean) })}
            placeholder="e.g. pdf, jpg, png"
            class="h-7 text-xs"
          />
        </div>
      </div>
    {/if}

    {#if field.field_type === 'table'}
      <Separator />
      <div>
        <div class="mb-2 flex items-center justify-between">
          <span class="text-xs font-medium">Columns</span>
          <button type="button" class="flex items-center gap-1 rounded px-1.5 py-0.5 text-xs text-primary hover:bg-accent" onclick={addColumn}>
            <Plus class="size-3" /> Add
          </button>
        </div>
        <div class="space-y-2">
          {#each field.metadata.columns || [] as col, ci}
            <div class="rounded border bg-muted/30 p-2">
              <div class="mb-1 flex items-center justify-between">
                <span class="text-[11px] text-muted-foreground">Column {ci + 1}</span>
                <button type="button" class="rounded p-0.5 text-muted-foreground hover:text-destructive" onclick={() => removeColumn(ci)} aria-label="Remove column">
                  <X class="size-3" />
                </button>
              </div>
              <div class="grid grid-cols-2 gap-1.5">
                <Input value={col.key} oninput={(e: any) => updateColumn(ci, 'key', e.target.value)} placeholder="Key" class="h-6 text-[11px]" />
                <Input value={col.label} oninput={(e: any) => updateColumn(ci, 'label', e.target.value)} placeholder="Label" class="h-6 text-[11px]" />
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>
</aside>
