<script lang="ts">
  import { FileText, TriangleAlert } from '@lucide/svelte'
  import { Button } from '/components/ui/button'
  import { Input } from '/components/ui/input'
  import * as Sheet from '/components/ui/sheet'
  import { FIELD_TYPE_LABELS, type FormField } from '/components/customs/form-builder/types'
  import type { ConfirmTarget, SummaryItem } from '/lib/pdf-import-modal'

  type Props = {
    formName?: string
    description?: string
    fieldCount?: number
    fields: FormField[]
    summaryItems: SummaryItem[]
    visibleWarnings: string[]
    fileName: string
    errorMessage: string
    confirmingTarget?: ConfirmTarget | null
    onDismissWarning: (warning: string) => void
    onResetToUpload: () => void
    onConfirm: (target: ConfirmTarget) => void | Promise<void>
  }

  let {
    formName = $bindable(''),
    description,
    fieldCount = 0,
    fields = [],
    summaryItems = [],
    visibleWarnings = [],
    fileName = 'PDF import',
    errorMessage = '',
    confirmingTarget = null,
    onDismissWarning,
    onResetToUpload,
    onConfirm,
  }: Props = $props()

  function isConfirming(target: ConfirmTarget): boolean {
    return confirmingTarget === target
  }

  function confirmButtonLabel(target: ConfirmTarget): string {
    if (isConfirming(target)) {
      return 'Creating...'
    }

    return target === 'index' ? 'Create form' : 'Create & Edit'
  }
</script>

<div class="space-y-5" data-testid="pdf-import-preview-state">
  <div class="rounded-xl border border-border/60 bg-background p-5 shadow-sm">
    <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
      <div class="flex-1 space-y-3">
        <div class="space-y-2">
          <label class="text-sm font-medium text-foreground" for="pdf-import-form-name">Form name</label>
          <Input id="pdf-import-form-name" bind:value={formName} disabled={confirmingTarget !== null} />
        </div>

        {#if description}
          <p class="text-sm text-muted-foreground">{description}</p>
        {/if}
      </div>

      <div class="min-w-40 rounded-xl border border-border/60 bg-muted/20 p-4 lg:max-w-48">
        <p class="text-xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">Preview</p>
        <p class="mt-2 text-3xl font-semibold text-foreground">{fieldCount}</p>
        <p class="text-sm text-muted-foreground">field{fieldCount === 1 ? '' : 's'} detected</p>
      </div>
    </div>

    {#if summaryItems.length > 0}
      <div class="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        {#each summaryItems as item}
          <div class="rounded-xl border border-border/60 bg-background px-4 py-3">
            <p class="text-xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">{item.label}</p>
            <p class="mt-1 text-2xl font-semibold text-foreground">{item.count}</p>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  {#if errorMessage}
    <div class="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700" role="alert">
      {errorMessage}
    </div>
  {/if}

  {#if visibleWarnings.length > 0}
    <div class="space-y-3">
      {#each visibleWarnings as warning}
        <div class="flex items-start justify-between gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900" role="status">
          <div class="flex items-start gap-3">
            <TriangleAlert class="mt-0.5 size-4 shrink-0 text-amber-600" aria-hidden="true" />
            <span>{warning}</span>
          </div>
          <button
            type="button"
            class="text-xs font-semibold uppercase tracking-[0.12em] text-amber-700"
            aria-label={`Dismiss warning: ${warning}`}
            onclick={() => onDismissWarning(warning)}
            disabled={confirmingTarget !== null}
          >
            Dismiss
          </button>
        </div>
      {/each}
    </div>
  {/if}

  <div class="rounded-xl border border-border/60 bg-background p-5">
    <div class="flex items-center justify-between gap-3 border-b border-border/60 pb-3">
      <div>
        <p class="font-semibold text-foreground">Detected fields</p>
        <p class="text-sm text-muted-foreground">Review labels and field types before creating the form.</p>
      </div>
      <div class="flex items-center gap-2 rounded-full bg-muted/40 px-3 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">
        <FileText class="size-3.5" aria-hidden="true" />
        {fileName}
      </div>
    </div>

    <div class="mt-4 max-h-[420px] space-y-3 overflow-auto pr-1">
      {#each fields as field, index}
        <div class="flex items-start justify-between gap-4 rounded-xl border border-border/60 px-4 py-3">
          <div>
            <p class="font-medium text-foreground">{index + 1}. {field.label}</p>
            {#if field.metadata?.description}
              <p class="mt-1 text-sm text-muted-foreground">{field.metadata.description}</p>
            {/if}
          </div>
          <div class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">
            {FIELD_TYPE_LABELS[field.field_type] || field.field_type}
          </div>
        </div>
      {/each}
    </div>
  </div>

  <div class="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950" role="note" data-testid="pdf-import-review-reminder">
    <TriangleAlert class="mt-0.5 size-4 shrink-0 text-amber-600" aria-hidden="true" />
    <p>Your form can contain typos or input errors. Always verify it before showing it to the client.</p>
  </div>

  <Sheet.Footer class="gap-2 sm:justify-between">
    <Button type="button" variant="secondary" onclick={onResetToUpload} disabled={confirmingTarget !== null}>Try again</Button>
    <div class="flex flex-col gap-2 sm:flex-row">
      <Button type="button" variant="outline" onclick={() => onConfirm('index')} disabled={confirmingTarget !== null}>
        {confirmButtonLabel('index')}
      </Button>
      <Button type="button" onclick={() => onConfirm('edit')} disabled={confirmingTarget !== null}>
        {confirmButtonLabel('edit')}
      </Button>
    </div>
  </Sheet.Footer>
</div>
