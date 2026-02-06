<script lang="ts">
  const { client, form } = $props();
</script>

<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
  <section class="max-w-3xl mx-auto rounded-lg border border-border bg-background p-6 text-center">
    <h1 class="text-2xl font-semibold text-foreground">Submission Confirmed</h1>

    {#if client}
      <p class="mt-2 text-sm text-muted-foreground">Thank you, <strong>{client.name}</strong>. Your response for <strong>{form?.name}</strong> has been submitted and locked.</p>
    {:else}
      <p class="mt-2 text-sm text-muted-foreground">Your response has been submitted and locked.</p>
    {/if}

    <div class="mt-4 flex justify-center gap-3">
      <a href="/" class="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground no-underline">Return to Home</a>
    </div>
  </section>
</main>
