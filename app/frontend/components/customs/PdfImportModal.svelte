<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import { FileText, Loader2, Sparkles, TriangleAlert, Upload } from '@lucide/svelte';
  import { onDestroy } from 'svelte';
  import { Button } from '/components/ui/button';
  import { Input } from '/components/ui/input';
  import { Skeleton } from '/components/ui/skeleton';
  import * as Sheet from '/components/ui/sheet';
  import { FIELD_TYPE_LABELS, type FormField, type FormSettings } from '/components/customs/form-builder/types';
  import { confirm_form_imports_path, edit_form_path, form_imports_path, forms_path } from '@/routes';

  type ModalState = 'idle' | 'uploading' | 'preview' | 'error';
  type ConfirmTarget = 'edit' | 'index';

  interface PreviewFormData {
    name: string;
    structure: {
      description?: string;
      settings?: FormSettings;
      fields: FormField[];
    };
  }

  interface PdfImportResult {
    form_data: PreviewFormData;
    warnings: string[];
    field_count: number;
  }

  interface SummaryItem {
    key: string;
    label: string;
    count: number;
  }

  const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024;
  const SLOW_UPLOAD_MESSAGES = [
    'Your pdf is still being processed',
    'Yes, still on process',
    'Not crashing yet...',
    'Hold on i heard something :o',
    "Oh no, i canno't hear i'm a web app...",
    'Wow, are you on 64kB connection?',
    'Did you gave a book to process?!',
    'Maybe there is a problem on the server side...',
    "At worse the biggest AI out there might process your pdf, cost a bunch, but when it's for you... $.$",
    "If you see that message, 55 seconds have passed at least... there might be problem somewhere. You can reload the page and retry.",
  ] as const;

  let { open = $bindable(false) } = $props();

  let modalState: ModalState = $state('idle');
  let file: File | null = $state(null);
  let result: PdfImportResult | null = $state(null);
  let errorMessage = $state('');
  let dragOver = $state(false);
  let fileInput: HTMLInputElement | null = $state(null);
  let confirmingTarget: ConfirmTarget | null = $state(null);
  let dismissedWarnings: string[] = $state([]);
  let slowUploadMessageVisible = $state(false);
  let slowUploadMessageIndex = $state(0);
  let uploadSequence = $state(0);
  let allowModalClose = false;
  let requestVersion = 0;
  let slowUploadTimeout: ReturnType<typeof setTimeout> | null = null;
  let slowUploadInterval: ReturnType<typeof setInterval> | null = null;

  $effect(() => {
    if (!open) {
      if (confirmingTarget !== null && !allowModalClose) {
        open = true;
        return;
      }

      invalidatePendingRequests();
      resetState();
    }
  });

  $effect(() => {
    if (!open || modalState !== 'uploading') {
      stopSlowUploadMessages();
      return;
    }

    startSlowUploadMessages(uploadSequence);

    return () => {
      clearSlowUploadTimers();
    };
  });

  onDestroy(() => {
    invalidatePendingRequests();
    stopSlowUploadMessages();
  });

  const previewFields = $derived.by((): FormField[] => {
    if (!result) return [];
    return result.form_data.structure.fields;
  });

  const visibleWarnings = $derived.by(() => {
    if (!result?.warnings?.length) return [];
    return result.warnings.filter((warning: string) => !dismissedWarnings.includes(warning));
  });

  const summaryItems = $derived.by<SummaryItem[]>(() => {
    if (!previewFields.length) return [];

    const counts = {
      inputs: 0,
      choices: 0,
      uploads: 0,
      tables: 0,
      layout: 0,
    };

    for (const field of previewFields) {
      switch (field.field_type) {
        case 'text':
        case 'number':
        case 'email':
        case 'date':
        case 'textarea':
          counts.inputs += 1;
          break;
        case 'checkbox':
        case 'buttons':
        case 'select':
        case 'radio':
          counts.choices += 1;
          break;
        case 'file':
          counts.uploads += 1;
          break;
        case 'table':
          counts.tables += 1;
          break;
        default:
          counts.layout += 1;
      }
    }

    return [
      { key: 'inputs', label: 'Inputs', count: counts.inputs },
      { key: 'choices', label: 'Choices', count: counts.choices },
      { key: 'uploads', label: 'Uploads', count: counts.uploads },
      { key: 'tables', label: 'Tables', count: counts.tables },
      { key: 'layout', label: 'Layout', count: counts.layout },
    ].filter((item) => item.count > 0);
  });

  function resetState() {
    stopSlowUploadMessages();
    modalState = 'idle';
    file = null;
    result = null;
    errorMessage = '';
    dragOver = false;
    confirmingTarget = null;
    dismissedWarnings = [];
    allowModalClose = false;
    if (fileInput) fileInput.value = '';
  }

  function openFilePicker() {
    fileInput?.click();
  }

  function invalidatePendingRequests() {
    requestVersion += 1;
  }

  function clearSlowUploadTimers() {
    if (slowUploadTimeout !== null) {
      clearTimeout(slowUploadTimeout);
      slowUploadTimeout = null;
    }

    if (slowUploadInterval !== null) {
      clearInterval(slowUploadInterval);
      slowUploadInterval = null;
    }
  }

  function resetSlowUploadMessage() {
    slowUploadMessageVisible = false;
    slowUploadMessageIndex = 0;
  }

  function stopSlowUploadMessages() {
    clearSlowUploadTimers();
    resetSlowUploadMessage();
  }

  function startSlowUploadMessages(_sequence: number) {
    clearSlowUploadTimers();
    resetSlowUploadMessage();

    slowUploadTimeout = setTimeout(() => {
      slowUploadTimeout = null;
      slowUploadMessageVisible = true;
      slowUploadMessageIndex = 0;

      slowUploadInterval = setInterval(() => {
        if (slowUploadMessageIndex >= SLOW_UPLOAD_MESSAGES.length - 1) {
          clearSlowUploadTimers();
          return;
        }

        slowUploadMessageIndex += 1;
      }, 5000);
    }, 5000);
  }

  function isPdfFile(selectedFile: File): boolean {
    const normalizedName = selectedFile.name.toLowerCase();
    return selectedFile.type === 'application/pdf' || normalizedName.endsWith('.pdf');
  }

  function validateClientFile(selectedFile: File): string | null {
    if (!isPdfFile(selectedFile)) {
      return 'Only PDF files are accepted.';
    }

    if (selectedFile.size > MAX_FILE_SIZE_BYTES) {
      return 'File too large (max 10 MB).';
    }

    return null;
  }

  function dismissWarning(warning: string) {
    dismissedWarnings = [...dismissedWarnings, warning];
  }

  function resetToUpload() {
    invalidatePendingRequests();
    stopSlowUploadMessages();
    modalState = 'idle';
    file = null;
    result = null;
    errorMessage = '';
    dismissedWarnings = [];
    confirmingTarget = null;
    if (fileInput) fileInput.value = '';
  }

  function handleDragOver(event: DragEvent) {
    event.preventDefault();
    dragOver = true;
  }

  function handleDragLeave(event: DragEvent) {
    event.preventDefault();
    dragOver = false;
  }

  async function handleDrop(event: DragEvent) {
    event.preventDefault();
    dragOver = false;
    const selectedFile = event.dataTransfer?.files?.[0];
    if (selectedFile) {
      await startUpload(selectedFile);
    }
  }

  async function handleFileInputChange(event: Event) {
    const target = event.currentTarget as HTMLInputElement;
    const selectedFile = target.files?.[0];
    if (selectedFile) {
      await startUpload(selectedFile);
    }
  }

  async function startUpload(selectedFile: File) {
    const currentRequestVersion = requestVersion + 1;
    requestVersion = currentRequestVersion;
    stopSlowUploadMessages();
    const validationError = validateClientFile(selectedFile);

    if (validationError) {
      file = selectedFile;
      result = null;
      errorMessage = validationError;
      modalState = 'error';
      if (fileInput) fileInput.value = '';
      return;
    }

    file = selectedFile;
    errorMessage = '';
    result = null;
    dismissedWarnings = [];
    modalState = 'uploading';
    uploadSequence += 1;

    const csrfToken = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '';
    const formData = new FormData();
    formData.append('pdf_file', selectedFile);

    try {
      const response = await fetch(form_imports_path(), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': csrfToken,
        },
        body: formData,
      });

      const payload = await response.json().catch(() => null);

      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      if (!response.ok || !payload?.success) {
        errorMessage = buildErrorMessage(payload?.error, payload?.details);
        modalState = 'error';
        return;
      }

      result = payload as PdfImportResult;
      modalState = 'preview';
    } catch {
      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      errorMessage = 'Network error. Please try again.';
      modalState = 'error';
    } finally {
      if (fileInput) fileInput.value = '';
    }
  }

  async function confirmForm(target: ConfirmTarget) {
    if (!result) return;

    const currentRequestVersion = requestVersion + 1;
    requestVersion = currentRequestVersion;
    confirmingTarget = target;
    errorMessage = '';

    const csrfToken = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '';

    try {
      const response = await fetch(confirm_form_imports_path(), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
        },
        body: JSON.stringify({ form_data: result.form_data }),
      });

      const payload = await response.json().catch(() => null);

      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      if (!response.ok || !payload?.success) {
        errorMessage = buildErrorMessage(payload?.error, payload?.details) || 'Could not create the form.';
        return;
      }

      allowModalClose = true;
      open = false;
      router.visit(target === 'edit' ? edit_form_path(payload.form_id) : forms_path());
    } catch {
      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      errorMessage = 'Network error. Please try again.';
    } finally {
      if (currentRequestVersion === requestVersion) {
        confirmingTarget = null;
      }
    }
  }

  function buildErrorMessage(error?: string, details?: unknown): string {
    if (!details || !Array.isArray(details) || details.length === 0) {
      return error || 'Import failed.';
    }

    return `${error || 'Import failed.'} ${details.join(' ')}`.trim();
  }

  function isConfirming(target: ConfirmTarget): boolean {
    return confirmingTarget === target;
  }
</script>

<Sheet.Root bind:open>
  <Sheet.Content
    side="right"
    class="w-full overflow-y-auto sm:max-w-2xl"
    showCloseButton={false}
    interactOutsideBehavior={confirmingTarget !== null ? 'ignore' : 'close'}
    escapeKeydownBehavior={confirmingTarget !== null ? 'ignore' : 'close'}
  >
    <Sheet.Header>
      <Sheet.Title>Import from PDF</Sheet.Title>
      <Sheet.Description>
        Upload a PDF form and generate a draft Quick KYB form structure before you create it.
      </Sheet.Description>
    </Sheet.Header>

    <div class="mt-4 flex justify-end">
      <Button type="button" variant="ghost" onclick={() => (open = false)} disabled={confirmingTarget !== null} data-testid="pdf-import-close">Close</Button>
    </div>

    <div class="mt-6 space-y-6">
      {#if modalState === 'idle'}
        <div class="space-y-4" data-testid="pdf-import-idle-state">
          <button
            type="button"
            class={`flex w-full flex-col items-center justify-center rounded-2xl border-2 border-dashed px-6 py-12 text-center transition-colors ${dragOver ? 'border-blue-400 bg-blue-50/70' : 'border-border bg-muted/20 hover:border-muted-foreground/40 hover:bg-muted/40'}`}
            onclick={openFilePicker}
            ondrop={handleDrop}
            ondragover={handleDragOver}
            ondragleave={handleDragLeave}
            aria-label="Upload PDF"
            data-testid="pdf-import-dropzone"
          >
            <div class="mb-4 rounded-full bg-background p-4 shadow-sm">
              <Upload class="size-8 text-foreground" aria-hidden="true" />
            </div>
            <p class="text-base font-semibold text-foreground">Drop your PDF here or click to browse</p>
            <p class="mt-2 text-sm text-muted-foreground">Single PDF file, up to 10 MB.</p>
          </button>

          <input
            bind:this={fileInput}
            id="pdf-import-input"
            type="file"
            accept=".pdf,application/pdf"
            class="sr-only"
            tabindex="-1"
            aria-label="Upload PDF file"
            onchange={handleFileInputChange}
            data-testid="pdf-import-input"
          />

          <div class="rounded-xl border border-border/60 bg-muted/20 p-4 text-sm text-muted-foreground">
            Gemini reads the uploaded PDF directly. The app will validate the generated structure before you can create the form.
          </div>
        </div>
      {:else if modalState === 'uploading'}
        <div class="space-y-5" data-testid="pdf-import-uploading-state" aria-busy="true">
          <div class="rounded-xl border border-border/60 bg-slate-50 p-4">
            <div class="flex items-center gap-3 text-slate-900">
              <div class="rounded-full bg-white p-2 shadow-sm">
                <Sparkles class="size-5" aria-hidden="true" />
              </div>
              <div>
                <p class="font-semibold">Analyzing your PDF...</p>
                <p class="text-sm text-slate-600" role="status" aria-live="polite" aria-atomic="true">
                  {slowUploadMessageVisible ? SLOW_UPLOAD_MESSAGES[slowUploadMessageIndex] : 'This usually takes a few seconds.'}
                </p>
              </div>
            </div>
          </div>

          <div class="rounded-xl border border-border/60 bg-background p-5">
            <div class="mb-4 flex items-center gap-3">
              <Loader2 class="size-5 animate-spin text-blue-600" aria-hidden="true" />
              <div>
                <p class="font-medium text-foreground">{file?.name}</p>
                <p class="text-sm text-muted-foreground">Generating a preview structure</p>
              </div>
            </div>

            <div class="space-y-3">
              <Skeleton class="h-10 w-2/3" />
              <Skeleton class="h-20 w-full" />
              {#each Array(5) as _}
                <div class="flex items-center gap-3 rounded-lg border border-border/60 p-3">
                  <Skeleton class="size-9 rounded-full" />
                  <div class="flex-1 space-y-2">
                    <Skeleton class="h-4 w-1/2" />
                    <Skeleton class="h-3 w-1/3" />
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>
      {:else if modalState === 'preview' && result}
        <div class="space-y-5" data-testid="pdf-import-preview-state">
          <div class="rounded-xl border border-border/60 bg-background p-5 shadow-sm">
            <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
              <div class="flex-1 space-y-3">
                <div class="space-y-2">
                  <label class="text-sm font-medium text-foreground" for="pdf-import-form-name">Form name</label>
                  <Input id="pdf-import-form-name" bind:value={result.form_data.name} disabled={confirmingTarget !== null} />
                </div>

                {#if result.form_data.structure.description}
                  <p class="text-sm text-muted-foreground">{result.form_data.structure.description}</p>
                {/if}
              </div>

              <div class="min-w-40 rounded-xl border border-border/60 bg-muted/20 p-4 lg:max-w-48">
                <p class="text-xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">Preview</p>
                <p class="mt-2 text-3xl font-semibold text-foreground">{result.field_count}</p>
                <p class="text-sm text-muted-foreground">field{result.field_count === 1 ? '' : 's'} detected</p>
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
                  <button type="button" class="text-xs font-semibold uppercase tracking-[0.12em] text-amber-700" aria-label={`Dismiss warning: ${warning}`} onclick={() => dismissWarning(warning)} disabled={confirmingTarget !== null}>
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
                {file?.name || 'PDF import'}
              </div>
            </div>

            <div class="mt-4 max-h-[420px] space-y-3 overflow-auto pr-1">
              {#each previewFields as field, index}
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
            <Button type="button" variant="secondary" onclick={resetToUpload} disabled={confirmingTarget !== null}>Try again</Button>
            <div class="flex flex-col gap-2 sm:flex-row">
              <Button type="button" variant="outline" onclick={() => confirmForm('index')} disabled={confirmingTarget !== null}>
                {isConfirming('index') ? 'Creating...' : 'Create form'}
              </Button>
              <Button type="button" onclick={() => confirmForm('edit')} disabled={confirmingTarget !== null}>
                {isConfirming('edit') ? 'Creating...' : 'Create & Edit'}
              </Button>
            </div>
          </Sheet.Footer>
        </div>
      {:else}
        <div class="space-y-4" data-testid="pdf-import-error-state">
          <div class="rounded-xl border border-red-200 bg-red-50 px-4 py-4 text-sm text-red-700" role="alert">
            {errorMessage || 'Import failed. Please try again.'}
          </div>

          <div class="rounded-xl border border-border/60 bg-background p-4 text-sm text-muted-foreground">
            {#if file}
              <p class="font-medium text-foreground">{file.name}</p>
              <p class="mt-1">Choose another PDF or upload the same file again after adjusting it.</p>
            {:else}
              <p>Choose a PDF file and try again.</p>
            {/if}
          </div>

          <Sheet.Footer class="justify-start">
            <Button type="button" variant="secondary" onclick={resetToUpload}>Try again</Button>
          </Sheet.Footer>
        </div>
      {/if}
    </div>
  </Sheet.Content>
</Sheet.Root>