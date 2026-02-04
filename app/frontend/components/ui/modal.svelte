<script lang="ts">
  let { showModal = $bindable(false), open = undefined, title = '', description = '', onClose = () => {}, onConfirm = () => {}, header = undefined, children = undefined } = $props();

  // Keep backward compatibility with `open` prop if provided.
  $effect(() => {
    if (open !== undefined && open !== showModal) showModal = open;
  });

  // Callbacks
  function close() {
    showModal = false;
    onClose();
  }

  function confirm() {
    onConfirm();
    showModal = false;
  }
</script>

{#if showModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="dialog" aria-modal="true" aria-label={title ? `${title} dialog` : 'Dialog'}>
    <div class="bg-white p-6 rounded-md w-full max-w-md">
      <header>
        {#if header}
          {@render header()}
        {:else}
          <h2 class="text-lg font-semibold">{title}</h2>
          {#if description}<p class="text-sm text-muted-foreground">{description}</p>{/if}
        {/if}
      </header>
      <div class="mt-4">
        {@render children?.()}
      </div>

      <div class="mt-4 flex justify-end gap-2">
        <button class="px-3 py-1 rounded bg-gray-200" onclick={close} type="button" aria-label="Cancel">Cancel</button>
        <button class="px-3 py-1 rounded bg-red-600 text-white" onclick={confirm} type="button" aria-label="Confirm">Delete</button>
      </div>
    </div>
  </div>
{/if}
