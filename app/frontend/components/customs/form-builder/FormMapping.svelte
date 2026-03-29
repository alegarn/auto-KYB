<script lang="ts">
  import { page } from "@inertiajs/svelte";
  import { Input } from "@/components/ui/input/index.js";
  import { Label } from "@/components/ui/label/index.js";
  import { Button } from "@/components/ui/button/index.js";
  import { Info, AlertCircle } from "@lucide/svelte";
  import Modal from "@/components/ui/modal.svelte";
  import { isLayoutField, type FormField } from "./types";
  import { fromCrmKey } from "@/lib/crm-utils";

  interface Props {
    fields: FormField[];
    onupdate: (index: number, patch: Partial<FormField>) => void;
    showValidation?: boolean;
    duplicateKeys?: string[];
  }

  let { fields, onupdate, showValidation = false, duplicateKeys = [] }: Props = $props();

  let showSyncModal = $state(false);

  // @ts-ignore
  const canUseCrm = $derived($page.props.auth?.user?.can_use_crm);

  const dataFields = $derived(
    fields.map((f, i) => ({ field: f, index: i })).filter(
      ({ field }) => !isLayoutField(field.field_type)
    )
  );

  const activeProviders = $derived(
    Array.from(new Set(
      dataFields.flatMap(({ field }) => Object.keys(field.metadata?.crm_mapping || {}))
    ))
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
        // Find first provider that has a property name and is NOT read-only
        const firstActiveMapping: any = Object.values(crmMapping).find((m: any) => m.property_name && !m.read_only);
        if (firstActiveMapping?.property_name && firstActiveMapping.type === 'existing') {
          // Strip compound key prefix — export_key is user-facing (CSV/JSON)
          onupdate(index, { 
            metadata: { 
              ...field.metadata, 
              export_key: fromCrmKey(firstActiveMapping.property_name).propertyName 
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
      {#if canUseCrm}
        <Button 
          variant="outline" 
          size="sm" 
          class="border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100" 
          onclick={() => showSyncModal = true}
        >
          sync with CRM
        </Button>
      {/if}
    </div>
  {/if}

  <Modal
    bind:showModal={showSyncModal}
    title="Sync with CRM?"
    description={`This will overwrite your current Export Keys with the technical property names from your ${activeProviders.length > 0 ? activeProviders.join(' & ') : 'CRM'}. This action cannot be undone.`}
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

        {#each Object.entries(field.metadata?.crm_mapping || {}) as [provider, mapping]}
          {#if mapping.type === 'custom'}
            <div class="flex items-start gap-2 rounded-md bg-blue-50/50 p-2 text-[10px] text-blue-700 border border-blue-100/50">
              <Info class="size-3 shrink-0 mt-0.5" />
              <p>
                Mapped to a <strong>{provider}</strong> custom property. This field will create a new property in your CRM upon export.
              </p>
            </div>
          {:else if mapping.read_only}
            <div class="flex items-start gap-2 rounded-md bg-destructive/5 p-2 text-[10px] text-destructive border border-destructive/20">
              <AlertCircle class="size-3 shrink-0 mt-0.5" />
              <div class="space-y-1">
                <p>
                  Mapped to <strong>{mapping.property_name}</strong> ({provider}), which is <strong>read-only</strong> on the CRM. 
                </p>
                <p class="font-medium opacity-90">
                  Tip: Use the "Mapping" button to switch to a <strong>Custom Property</strong> or another writable field.
                </p>
              </div>
            </div>
          {/if}
        {/each}
      </div>
    {/each}

    {#if dataFields.length === 0}
      <p class="text-xs text-muted-foreground text-center py-4">
        No data fields added yet.
      </p>
    {/if}
  </div>
</aside>
