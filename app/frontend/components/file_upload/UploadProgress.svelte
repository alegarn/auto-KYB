<script lang="ts">
  interface Props {
    percentage: number
    status: 'idle' | 'uploading' | 'retrying' | 'success' | 'error'
    errorMessage?: string | null
  }

  const { percentage, status, errorMessage = null }: Props = $props()

  const barColor = $derived.by(() => {
    if (status === 'error') return 'bg-red-500'
    if (status === 'success') return 'bg-emerald-500'
    if (status === 'retrying') return 'bg-amber-500'
    return 'bg-blue-500'
  })

  const statusLabel = $derived.by(() => {
    if (status === 'uploading') return `Uploading... ${percentage}%`
    if (status === 'retrying') return 'Retrying upload...'
    if (status === 'success') return 'Upload complete'
    if (status === 'error') return errorMessage || 'Upload failed'
    return ''
  })
</script>

{#if status !== 'idle'}
  <div class="mt-2 space-y-1" role="progressbar" aria-valuenow={percentage} aria-valuemin={0} aria-valuemax={100} aria-label="File upload progress">
    <div class="h-2 w-full rounded-full bg-muted overflow-hidden">
      <div
        class={`h-full rounded-full transition-all duration-300 ${barColor}`}
        style:width={`${percentage}%`}
      ></div>
    </div>
    <p class={`text-xs ${status === 'error' ? 'text-red-600' : 'text-muted-foreground'}`}>
      {statusLabel}
    </p>
  </div>
{/if}
