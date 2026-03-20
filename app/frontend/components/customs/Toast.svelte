<script lang="ts">
  import { router } from '@inertiajs/svelte'
  const { message, type, actionHref, actionLabel }: {
    message?: string;
    type?: 'notice' | 'alert' | string;
    actionHref?: string;
    actionLabel?: string;
  } = $props()

  const classes = () => {
    return type === 'notice'
      ? 'mb-4 rounded-md p-4 text-sm bg-green-50 text-green-700'
      : 'mb-4 rounded-md p-4 text-sm bg-red-50 text-red-700'
  }

  function dismiss() {
    // clear client-side toast
    try {
      router.flash('toast', null)
    } catch (err) {
      try {
        router.replace({ props: (p: any) => ({ ...p, flash: null }) })
      } catch (err2) {
        console.error('Failed to clear flash', err2)
      }
    }
  }
</script>

<div role="status" aria-live="polite" class={classes()}>
  <div class="flex items-start justify-between gap-4">
    <div class="text-sm">{message ?? ''}</div>
    <div class="flex items-center gap-2">
      {#if actionHref && actionLabel}
        <a href={actionHref} class="text-sm font-semibold underline">{actionLabel}</a>
      {/if}
      <button aria-label="Dismiss" class="ml-4 text-sm font-semibold" onclick={dismiss}>×</button>
    </div>
  </div>
</div>
