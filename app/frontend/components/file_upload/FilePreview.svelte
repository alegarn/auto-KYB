<script lang="ts">
  import { FileText, Image, X } from '@lucide/svelte'

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
    file: UploadedFileData
    onRemove?: () => void
    showRemove?: boolean
  }

  const { file, onRemove, showRemove = true }: Props = $props()

  const isImage = $derived(file.content_type?.startsWith('image/'))

  function formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }
</script>

<div class="flex items-center gap-3 rounded-md border border-border bg-background p-3">
  <div class="flex size-10 shrink-0 items-center justify-center rounded-md bg-muted">
    {#if isImage}
      <Image class="size-5 text-muted-foreground" aria-hidden="true" />
    {:else}
      <FileText class="size-5 text-muted-foreground" aria-hidden="true" />
    {/if}
  </div>

  <div class="min-w-0 flex-1">
    <p class="truncate text-sm font-medium text-foreground">{file.filename}</p>
    <p class="text-xs text-muted-foreground">
      {formatSize(file.byte_size)} &middot; {formatDate(file.uploaded_at)}
    </p>
  </div>

  {#if showRemove && onRemove}
    <button
      type="button"
      class="shrink-0 rounded p-1 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
      onclick={onRemove}
      aria-label={`Remove ${file.filename}`}
    >
      <X class="size-4" />
    </button>
  {/if}
</div>
