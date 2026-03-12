<script lang="ts">
  import { Input } from "@/components/ui/input/index.js";
  import { Label } from "@/components/ui/label/index.js";
  import { Button } from "@/components/ui/button/index.js";
  import Modal from "@/components/ui/modal.svelte";
  import type { FormField } from "./types";

  interface Props {
    fields: FormField[];
    onupdate: (index: number, patch: Partial<FormField>) => void;
    showValidation?: boolean;
    duplicateKeys?: string[];
  }

  let { fields, onupdate, showValidation = false, duplicateKeys = [] }: Props = $props();

  let showSyncModal = $state(false);

  const dataFields = $derived(
    fields.map((f, i) => ({ field: f, index: i })).filter(
      ({ field }) => !['section', 'subtitle', 'static_text', 'separator', 'logo'].includes(field.field_type)
    )
  );

  const hasDuplicateKeys = $derived(duplicateKeys.length > 0);

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

  function syncAllKeysWithCrm() {
    dataFields.forEach(({ field, index }) => {
      const crmMapping = field.metadata?.crm_mapping;
      if (crmMapping) {
        // Find first provider that has a property name
        const firstActiveMapping: any = Object.values(crmMapping).find((m: any) => m.property_name);
        if (firstActiveMapping?.property_name) {
          onupdate(index, { 
            metadata: { 
              ...field.metadata, 
              export_key: firstActiveMapping.property_name 
            } 
          });
        }
      }
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

  {#if showValidation && hasDuplicateKeys}
    <div class="mb-4 rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-xs text-destructive">
      Not all fields are unique for export. Duplicate mapping keys found.
    </div>
  {/if}

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
      <Button 
        variant="outline" 
        size="sm" 
        class="border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100" 
        onclick={() => showSyncModal = true}
      >
        sync with CRM
      </Button>
    </div>
  {/if}

  <Modal
    bind:showModal={showSyncModal}
    title="Sync with CRM?"
    description="This will overwrite your current Export Keys with the technical property names from your CRM. This action cannot be undone."
    confirmText="Confirm Sync"
    onConfirm={syncAllKeysWithCrm}
  />

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
