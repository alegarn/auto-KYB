<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import { Loader2, Sparkles, Upload } from '@lucide/svelte';
  import { onDestroy } from 'svelte';
  import { Button } from '/components/ui/button';
  import { Skeleton } from '/components/ui/skeleton';
  import * as Sheet from '/components/ui/sheet';
  import PdfImportPreview from '/components/customs/pdf-import-modal/PdfImportPreview.svelte';
  import {
    buildConfirmedFormData,
    buildErrorMessage,
    buildSummaryItems,
    isConfirmSuccessPayload,
    isPdfImportResult,
    SLOW_UPLOAD_MESSAGE_DELAY_MS,
    SLOW_UPLOAD_MESSAGE_INTERVAL_MS,
    SLOW_UPLOAD_MESSAGES,
    validateClientFile,
    type ConfirmTarget,
    type ModalState,
    type PdfImportResult,
  } from '/lib/pdf-import-modal';
  import { confirm_form_imports_path, edit_form_path, form_imports_path, forms_path } from '/routes/index.js';

  let { open = $bindable(false) } = $props();

  let modalState: ModalState = $state('idle');
  let file: File | null = $state(null);
  let result: PdfImportResult | null = $state(null);
  let draftFormName = $state('');
  let errorMessage = $state('');
  let dragOver = $state(false);
  let fileInput: HTMLInputElement | null = $state(null);
  let confirmingTarget: ConfirmTarget | null = $state(null);
  let dismissedWarnings: string[] = $state([]);
  let slowUploadMessageVisible = $state(false);
  let slowUploadMessageIndex = $state(0);
  let allowModalClose = false;
  let requestVersion = 0;
  let uploadAbortController: AbortController | null = null;
  let confirmAbortController: AbortController | null = null;
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

    startSlowUploadMessages();

    return () => {
      clearSlowUploadTimers();
    };
  });

  onDestroy(() => {
    invalidatePendingRequests();
    stopSlowUploadMessages();
  });

  const previewFields = $derived.by(() => result?.form_data.structure.fields ?? []);

  const visibleWarnings = $derived.by(() => {
    if (!result?.warnings?.length) return [];
    return result.warnings.filter((warning: string) => !dismissedWarnings.includes(warning));
  });

  const summaryItems = $derived.by(() => buildSummaryItems(previewFields));

  function clearPreviewState() {
    result = null;
    draftFormName = '';
    dismissedWarnings = [];
    confirmingTarget = null;
  }

  function clearTransientState() {
    errorMessage = '';
    dragOver = false;
    allowModalClose = false;
  }

  function resetState() {
    stopSlowUploadMessages();
    modalState = 'idle';
    clearPreviewState();
    clearTransientState();
    file = null;
    if (fileInput) fileInput.value = '';
  }

  function openFilePicker() {
    fileInput?.click();
  }

  function invalidatePendingRequests() {
    requestVersion += 1;
    uploadAbortController?.abort();
    uploadAbortController = null;
    confirmAbortController?.abort();
    confirmAbortController = null;
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

  function startSlowUploadMessages() {
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
      }, SLOW_UPLOAD_MESSAGE_INTERVAL_MS);
    }, SLOW_UPLOAD_MESSAGE_DELAY_MS);
  }

  function dismissWarning(warning: string) {
    if (dismissedWarnings.includes(warning)) return;
    dismissedWarnings = [...dismissedWarnings, warning];
  }

  function resetToUpload() {
    invalidatePendingRequests();
    stopSlowUploadMessages();
    modalState = 'idle';
    clearPreviewState();
    clearTransientState();
    file = null;
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
    invalidatePendingRequests();
    stopSlowUploadMessages();
    clearPreviewState();
    clearTransientState();

    const validationError = validateClientFile(selectedFile);

    if (validationError) {
      file = selectedFile;
      errorMessage = validationError;
      modalState = 'error';
      if (fileInput) fileInput.value = '';
      return;
    }

    file = selectedFile;
    modalState = 'uploading';

    const currentRequestVersion = requestVersion;
    const controller = new AbortController();
    uploadAbortController = controller;
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
        signal: controller.signal,
      });

      const payload: unknown = await response.json().catch(() => null);

      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      if (!response.ok || !isPdfImportResult(payload)) {
        const errorPayload = (payload as { error?: string; details?: unknown } | null) ?? {};
        errorMessage = buildErrorMessage(errorPayload.error, errorPayload.details);
        modalState = 'error';
        return;
      }

      result = payload;
      draftFormName = payload.form_data.name;
      errorMessage = '';
      modalState = 'preview';
    } catch {
      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      if (controller.signal.aborted) {
        return;
      }

      errorMessage = 'Network error. Please try again.';
      modalState = 'error';
    } finally {
      if (uploadAbortController === controller) {
        uploadAbortController = null;
      }

      if (fileInput) fileInput.value = '';
    }
  }

  async function confirmForm(target: ConfirmTarget) {
    if (!result || confirmingTarget !== null) return;

    invalidatePendingRequests();
    confirmingTarget = target;
    errorMessage = '';

    const currentRequestVersion = requestVersion;
    const controller = new AbortController();
    confirmAbortController = controller;
    const csrfToken = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '';

    try {
      const response = await fetch(confirm_form_imports_path(), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
        },
        body: JSON.stringify({ form_data: buildConfirmedFormData(result.form_data, draftFormName) }),
        signal: controller.signal,
      });

      const payload: unknown = await response.json().catch(() => null);

      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      if (!response.ok || !isConfirmSuccessPayload(payload)) {
        const errorPayload = (payload as { error?: string; details?: unknown } | null) ?? {};
        errorMessage = buildErrorMessage(errorPayload.error, errorPayload.details, 'Could not create the form.');
        return;
      }

      allowModalClose = true;
      open = false;
      router.visit(target === 'edit' ? edit_form_path(payload.form_id) : forms_path());
    } catch {
      if (currentRequestVersion !== requestVersion || !open) {
        return;
      }

      if (controller.signal.aborted) {
        return;
      }

      errorMessage = 'Network error. Please try again.';
    } finally {
      if (confirmAbortController === controller) {
        confirmAbortController = null;
      }

      if (currentRequestVersion === requestVersion) {
        confirmingTarget = null;
      }
    }
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
        <PdfImportPreview
          bind:formName={draftFormName}
          description={result.form_data.structure.description}
          fieldCount={result.field_count}
          fields={previewFields}
          summaryItems={summaryItems}
          visibleWarnings={visibleWarnings}
          fileName={file?.name || 'PDF import'}
          errorMessage={errorMessage}
          confirmingTarget={confirmingTarget}
          onDismissWarning={dismissWarning}
          onResetToUpload={resetToUpload}
          onConfirm={confirmForm}
        />
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