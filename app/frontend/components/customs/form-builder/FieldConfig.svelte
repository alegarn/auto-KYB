<script lang="ts">
  import { FIELD_TYPE_LABELS, isLayoutField, type FormField, type FieldMetadata } from "./types";
  import { Input } from "@/components/ui/input/index.js";
  import { Label } from "@/components/ui/label/index.js";
  import { Separator } from "@/components/ui/separator/index.js";
  import { Textarea } from "@/components/ui/textarea/index.js";
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
  const isLayout = $derived(isLayoutField(field.field_type));

  function emitSection(key: string, value: any) {
    emitMeta('section', { ...field.metadata.section, [key]: value });
  }

  function emitSeparator(key: string, value: any) {
    emitMeta('separator', { ...field.metadata.separator, [key]: value });
  }

  function emitLogo(key: string, value: any) {
    emitMeta('logo', { ...field.metadata.logo, [key]: value });
  }
</script>

<aside class="rounded-lg border bg-card">
  <div class="border-b px-4 py-3">
    <h3 class="text-sm font-semibold">Field Settings</h3>
    <p class="text-xs text-muted-foreground">{FIELD_TYPE_LABELS[field.field_type]}</p>
  </div>

  <div class="space-y-4 p-4">
    {#if field.field_type === 'section'}
      <div>
        <Label for="cfg-label" class="mb-1.5 block text-xs font-medium">Section Title</Label>
        <Input
          id="cfg-label"
          value={field.label}
          oninput={(e: any) => emit({ label: e.target.value })}
          class="h-8 text-sm"
        />
      </div>
      <div>
        <Label for="cfg-section-desc" class="mb-1.5 block text-xs font-medium">Description</Label>
        <Input
          id="cfg-section-desc"
          value={field.metadata.description || ''}
          oninput={(e: any) => emitMeta('description', e.target.value)}
          class="h-8 text-sm"
          placeholder="Optional section description"
        />
      </div>
      <Separator />
      <div>
        <span class="mb-2 block text-xs font-medium">Section Options</span>
        <label class="mb-2 flex items-center gap-2">
          <input
            type="checkbox"
            checked={field.metadata.section?.collapsible || false}
            onchange={(e: any) => emitSection('collapsible', e.target.checked)}
            class="size-4 rounded border-border"
          />
          <span class="text-sm">Collapsible</span>
        </label>
        {#if field.metadata.section?.collapsible}
          <label class="mb-2 flex items-center gap-2">
            <input
              type="checkbox"
              checked={field.metadata.section?.default_expanded !== false}
              onchange={(e: any) => emitSection('default_expanded', e.target.checked)}
              class="size-4 rounded border-border"
            />
            <span class="text-sm">Expanded by default</span>
          </label>
        {/if}
        <div class="mt-3">
          <Label for="cfg-border-style" class="mb-1.5 block text-xs font-medium">Border Style</Label>
          <select
            id="cfg-border-style"
            class="h-8 w-full rounded-md border border-input bg-background px-3 text-sm"
            value={field.metadata.section?.border_style || 'subtle'}
            onchange={(e: any) => emitSection('border_style', e.target.value)}
          >
            <option value="none">None</option>
            <option value="subtle">Subtle</option>
            <option value="prominent">Prominent</option>
          </select>
        </div>
      </div>

    {:else if field.field_type === 'subtitle'}
      <div>
        <Label for="cfg-label" class="mb-1.5 block text-xs font-medium">Subtitle Text</Label>
        <Input
          id="cfg-label"
          value={field.label}
          oninput={(e: any) => emit({ label: e.target.value })}
          class="h-8 text-sm"
        />
      </div>
      <div>
        <Label for="cfg-subtitle-desc" class="mb-1.5 block text-xs font-medium">Description</Label>
        <Input
          id="cfg-subtitle-desc"
          value={field.metadata.description || ''}
          oninput={(e: any) => emitMeta('description', e.target.value)}
          class="h-8 text-sm"
          placeholder="Optional subtitle description"
        />
      </div>

    {:else if field.field_type === 'static_text'}
      <div>
        <Label for="cfg-label" class="mb-1.5 block text-xs font-medium">Block Title</Label>
        <Input
          id="cfg-label"
          value={field.label}
          oninput={(e: any) => emit({ label: e.target.value })}
          class="h-8 text-sm"
          placeholder="Information"
        />
      </div>
      <div>
        <Label for="cfg-text-content" class="mb-1.5 block text-xs font-medium">Text Content</Label>
        <Textarea
          id="cfg-text-content"
          value={field.metadata.text_content || ''}
          oninput={(e: any) => emitMeta('text_content', e.target.value)}
          class="min-h-[120px] text-sm"
          placeholder="Enter text to display on the form..."
        />
      </div>

    {:else if field.field_type === 'separator'}
      <div>
        <Label for="cfg-thickness" class="mb-1.5 block text-xs font-medium">Thickness</Label>
        <select
          id="cfg-thickness"
          class="h-8 w-full rounded-md border border-input bg-background px-3 text-sm"
          value={field.metadata.separator?.thickness || 'thin'}
          onchange={(e: any) => emitSeparator('thickness', e.target.value)}
        >
          <option value="thin">Thin</option>
          <option value="medium">Medium</option>
          <option value="thick">Thick</option>
        </select>
      </div>
      <div>
        <Label for="cfg-margin" class="mb-1.5 block text-xs font-medium">Spacing</Label>
        <select
          id="cfg-margin"
          class="h-8 w-full rounded-md border border-input bg-background px-3 text-sm"
          value={field.metadata.separator?.margin || 'medium'}
          onchange={(e: any) => emitSeparator('margin', e.target.value)}
        >
          <option value="small">Small</option>
          <option value="medium">Medium</option>
          <option value="large">Large</option>
        </select>
      </div>

    {:else if field.field_type === 'logo'}
      <div>
        <Label for="cfg-logo-url" class="mb-1.5 block text-xs font-medium">Image URL</Label>
        <Input
          id="cfg-logo-url"
          type="url"
          value={field.metadata.logo?.image_url || ''}
          oninput={(e: any) => emitLogo('image_url', e.target.value)}
          class="h-8 text-sm"
          placeholder="https://example.com/logo.png"
        />
      </div>
      <div class="grid grid-cols-2 gap-2">
        <div>
          <Label for="cfg-logo-width" class="mb-1.5 block text-xs font-medium">Width (px)</Label>
          <Input
            id="cfg-logo-width"
            type="number"
            value={field.metadata.logo?.width || ''}
            oninput={(e: any) => emitLogo('width', e.target.value ? Number(e.target.value) : undefined)}
            class="h-8 text-sm"
            placeholder="200"
          />
        </div>
        <div>
          <Label for="cfg-logo-height" class="mb-1.5 block text-xs font-medium">Height (px)</Label>
          <Input
            id="cfg-logo-height"
            type="number"
            value={field.metadata.logo?.height || ''}
            oninput={(e: any) => emitLogo('height', e.target.value ? Number(e.target.value) : undefined)}
            class="h-8 text-sm"
            placeholder="Auto"
          />
        </div>
      </div>
      <div>
        <Label for="cfg-logo-align" class="mb-1.5 block text-xs font-medium">Alignment</Label>
        <div class="flex gap-1">
          {#each ['left', 'center', 'right'] as align}
            <button
              type="button"
              class="flex-1 rounded-md border px-3 py-1.5 text-sm capitalize transition-colors {field.metadata.logo?.alignment === align ? 'border-primary bg-primary/10 text-primary' : 'border-input hover:bg-accent'}"
              onclick={() => emitLogo('alignment', align)}
            >
              {align}
            </button>
          {/each}
        </div>
      </div>

    {:else}
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
    {/if}

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
