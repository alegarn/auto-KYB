<script>
  const { client, form } = $props();
</script>

<main class="container">
  <h1>Submission Confirmed</h1>
  {#if client}
    <p>Thank you, {client.name}. Your response for <strong>{form?.name}</strong> has been submitted and locked.</p>
  {:else}
    <p>Your response has been submitted and locked.</p>
  {/if}

  <div>
    <a href="/">Return to site</a>
  </div>
</main>
