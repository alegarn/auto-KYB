<script lang="ts">
  import { Input } from "@/components/ui/input/index.js";
  import { Label } from "@/components/ui/label/index.js";
  import { Button } from "@/components/ui/button/index.js";
  import type { FormField } from "./types";

  interface Props {
    fields: FormField[];
    onupdate: (index: number, patch: Partial<FormField>) => void;
  }

  let { fields, onupdate }: Props = $props();

  // Filter out layout fields that don't have data
  const dataFields = $derived(
    fields.map((f, i) => ({ field: f, index: i })).filter(
      ({ field }) => !['section', 'subtitle', 'static_text', 'separator', 'logo'].includes(field.field_type)
    )
  );

  function toSnakeCase(str: string) {
    return str
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');
  }

  function toCamelCase(str: string) {
    return str
      .trim()
      .replace(/[^a-zA-Z0-9]+(.)/g, (_, chr) => chr.toUpperCase())
      .replace(/^[A-Z]/, (chr) => chr.toLowerCase());
  }

  function toKebabCase(str: string) {
    return str
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }

  function resetAllToDefault() {
    dataFields.forEach(({ field, index }) => {
      const newMeta = field.metadata ? { ...field.metadata } : {};
      if (Object.prototype.hasOwnProperty.call(newMeta, 'export_key')) {
        delete newMeta.export_key;
      }
      onupdate(index, { metadata: newMeta });
    });
  }

  function applyTransformToAll(transformFn: (str: string) => string) {
    dataFields.forEach(({ field, index }) => {
      const baseLabel = field.label || `Field ${index + 1}`;
      onupdate(index, {
        metadata: { ...field.metadata, export_key: transformFn(baseLabel) }
      });
    });
  }
</script>

<aside class="rounded-lg border bg-card p-4">
  <h3 class="mb-4 text-sm font-semibold">Data Export Mapping</h3>
  <p class="mb-4 text-xs text-muted-foreground">
    Customize the keys used when exporting form responses to CSV or JSON. If left blank, the field's label will be used.
  </p>

  {#if dataFields.length > 0}
    <div class="mb-4 flex flex-wrap gap-2">
      <Button variant="outline" size="sm" onclick={() => resetAllToDefault()}>
        default
      </Button>
      <Button variant="outline" size="sm" onclick={() => applyTransformToAll(toSnakeCase)}>
        snake_case
      </Button>
      <Button variant="outline" size="sm" onclick={() => applyTransformToAll(toKebabCase)}>
        kebab-case
      </Button>
      <Button variant="outline" size="sm" onclick={() => applyTransformToAll(toCamelCase)}>
        camelCase
      </Button>
    </div>
  {/if}

  <div class="space-y-4">
    {#each dataFields as { field, index }}
      <div class="space-y-1.5">
        <Label for={`mapping-${field.id || index}`} class="text-xs font-medium">
          {field.label || `Field ${index + 1}`}
        </Label>
        <Input
          id={`mapping-${field.id || index}`}
          type="text"
          placeholder={field.label || `Field ${index + 1}`}
          value={field.metadata?.export_key || ''}
          oninput={(e) => {
            const target = e.target as HTMLInputElement;
            onupdate(index, {
              metadata: { ...field.metadata, export_key: target.value }
            });
          }}
        />
      </div>
    {/each}

    {#if dataFields.length === 0}
      <p class="text-xs text-muted-foreground text-center py-4">
        No data fields added yet.
      </p>
    {/if}
  </div>
</aside>
