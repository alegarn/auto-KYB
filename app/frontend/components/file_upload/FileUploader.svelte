<script lang="ts">
  import { Upload } from '@lucide/svelte'
  import UploadProgress from './UploadProgress.svelte'
  import FilePreview from './FilePreview.svelte'
  import { client_portal_uploaded_files_path } from '@/routes'
  import { router } from '@inertiajs/svelte'

  interface UploadedFileData {
    id: string
    field_key: string
    filename: string
    content_type: string
    byte_size: number
    uploaded_at: string
    status: string
  }

  interface Props {
    fieldId: string
    existingFile?: UploadedFileData | null
    accept?: string
    maxSizeBytes?: number
    required?: boolean
    label?: string
  }

  const {
    fieldId,
    existingFile = null,
    accept = '.pdf,.jpg,.jpeg,.png',
    maxSizeBytes = 10 * 1024 * 1024,
    required = false,
    label = 'Upload file'
  }: Props = $props()

  const ALLOWED_TYPES = ['application/pdf', 'image/jpeg', 'image/png']
  const RETRY_DELAY_MS = 2000

  type UploadStatus = 'idle' | 'uploading' | 'retrying' | 'success' | 'error'

  let uploadStatus = $state<UploadStatus>('idle')
  let uploadPercentage = $state(0)
  let errorMessage = $state<string | null>(null)
  let uploadedFile = $state<UploadedFileData | null>(null)
  let fileInput = $state<HTMLInputElement | null>(null)
  let dragOver = $state(false)

  $effect(() => {
    uploadedFile = existingFile ?? null
  })

  function validateClientSide(file: File): string | null {
    if (!ALLOWED_TYPES.includes(file.type)) {
      return `File type "${file.type || 'unknown'}" is not supported. Allowed: PDF, JPEG, PNG`
    }
    if (file.size > maxSizeBytes) {
      const maxMb = Math.round(maxSizeBytes / (1024 * 1024))
      return `File exceeds maximum size of ${maxMb}MB`
    }
    return null
  }

  function handleFileSelect(event: Event) {
    const input = event.target as HTMLInputElement
    const file = input.files?.[0]
    if (file) startUpload(file)
  }

  function handleDrop(event: DragEvent) {
    event.preventDefault()
    dragOver = false
    const file = event.dataTransfer?.files?.[0]
    if (file) startUpload(file)
  }

  function handleDragOver(event: DragEvent) {
    event.preventDefault()
    dragOver = true
  }

  function handleDragLeave() {
    dragOver = false
  }

  async function startUpload(file: File, isRetry = false) {
    const clientError = validateClientSide(file)
    if (clientError) {
      errorMessage = clientError
      uploadStatus = 'error'
      return
    }

    errorMessage = null
    uploadStatus = isRetry ? 'retrying' : 'uploading'
    uploadPercentage = 0

    try {
      const result = await uploadFile(file)
      uploadedFile = result
      uploadStatus = 'success'
      uploadPercentage = 100
    } catch (err: any) {
      if (!isRetry) {
        setTimeout(() => startUpload(file, true), RETRY_DELAY_MS)
      } else {
        errorMessage = err.message || 'Upload failed. Please try again.'
        uploadStatus = 'error'
      }
    }
  }

  async function uploadFile(file: File): Promise<UploadedFileData> {
    const optimisticFile: UploadedFileData = {
      id: `temp-${Date.now()}`,
      field_key: fieldId,
      filename: file.name,
      content_type: file.type,
      byte_size: file.size,
      uploaded_at: new Date().toISOString(),
      status: 'available',
    }

    return new Promise((resolve, reject) => {
      router.post(
        client_portal_uploaded_files_path(),
        {
          file,
          field_key: fieldId,
        },
        {
          forceFormData: true,
          preserveScroll: true,
          preserveState: true,
          only: ['uploaded_files', 'flash_message'],
          onProgress: (progress) => {
            if (progress?.percentage != null) {
              uploadPercentage = Math.round(progress.percentage)
            }
          },
          onSuccess: (page) => {
            const flashMessage = (page?.props as any)?.flash_message
            if (flashMessage?.type === 'alert') {
              reject(new Error(flashMessage?.message || 'Upload failed. Please try again.'))
              return
            }

            uploadedFile = optimisticFile
            resolve(optimisticFile)
          },
          onError: () => {
            reject(new Error('Upload failed. Please try again.'))
          },
          onCancel: () => {
            reject(new Error('Upload cancelled. Please try again.'))
          },
        }
      )
    })
  }

  function removeFile() {
    uploadedFile = null
    uploadStatus = 'idle'
    uploadPercentage = 0
    errorMessage = null
    if (fileInput) fileInput.value = ''
  }

  function openFilePicker() {
    fileInput?.click()
  }
</script>

<div class="space-y-2">
  {#if uploadedFile && uploadStatus !== 'uploading' && uploadStatus !== 'retrying'}
    <FilePreview file={uploadedFile} onRemove={removeFile} />
  {:else}
    <button
      type="button"
      class="flex w-full cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed px-6 py-8 transition-colors
        {dragOver ? 'border-blue-400 bg-blue-50/50' : 'border-border hover:border-muted-foreground/50 hover:bg-muted/50'}"
      onclick={openFilePicker}
      ondrop={handleDrop}
      ondragover={handleDragOver}
      ondragleave={handleDragLeave}
      aria-label={label}
    >
      <Upload class="mb-2 size-8 text-muted-foreground" aria-hidden="true" />
      <span class="text-sm font-medium text-foreground">
        Click to upload or drag and drop
      </span>
      <span class="mt-1 text-xs text-muted-foreground">
        PDF, JPEG or PNG (max {Math.round(maxSizeBytes / (1024 * 1024))}MB)
      </span>
    </button>

    <input
      bind:this={fileInput}
      type="file"
      class="sr-only"
      {accept}
      {required}
      onchange={handleFileSelect}
      aria-label={label}
      tabindex={-1}
    />
  {/if}

  <UploadProgress
    percentage={uploadPercentage}
    status={uploadStatus}
    {errorMessage}
  />

  {#if uploadStatus === 'error'}
    <button
      type="button"
      class="text-sm font-medium text-blue-600 hover:text-blue-700 transition-colors"
      onclick={openFilePicker}
    >
      Try again
    </button>
  {/if}
</div>
