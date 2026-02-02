<script lang="ts">
  const { title, description, open, onClose, onConfirm } = $props();

  function close() {
    onClose?.();
  }

  function confirm() {
    onConfirm?.();
  }

  function handleBackdropClick() {
    close();
  }

  function onKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }

  function handleBackdropKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') {
      e.preventDefault();
      close();
    }
  }

  function stopDialogClick(e: MouseEvent) {
    e.stopPropagation();
  }

  $effect(() => {
    if (typeof window === 'undefined') return;
    if (!open) return;
    window.addEventListener('keydown', onKeydown);
    return () => window.removeEventListener('keydown', onKeydown);
  });

  $effect(() => {
    if (typeof window === 'undefined') return;
    if (open) {
      const el = document.getElementById('quick-kyb-modal-dialog');
      (el as HTMLElement | null)?.focus();
    }
  });
</script>

{#if open}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="button"
    aria-label={title ? `Close ${title}` : 'Close dialog'}
    tabindex="0"
    onclick={handleBackdropClick}
    onkeydown={handleBackdropKeydown}
  >
    <div
      id="quick-kyb-modal-dialog"
      class="bg-white rounded p-6 w-full max-w-md"
      role="dialog"
      aria-modal="true"
      aria-label={title || 'Dialog'}
      tabindex="-1"
      onclick={stopDialogClick}
    >
      <h3 class="text-lg font-medium">{title}</h3>
      {#if description}
        <p class="mt-2 text-sm text-muted-foreground">{description}</p>
      {/if}

      <slot />

      <div class="mt-4 flex justify-end gap-2">
        <button class="px-3 py-1 rounded bg-gray-200" onclick={close}>Cancel</button>
        <button class="px-3 py-1 rounded bg-red-600 text-white" onclick={confirm}>Delete</button>
      </div>
    </div>
  </div>
{/if}
