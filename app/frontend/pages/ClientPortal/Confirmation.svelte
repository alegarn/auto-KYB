<script lang="ts">
  const { client, form } = $props();
</script>

<style>
  .confirmation {
    max-width: 720px;
    margin: 2rem auto;
    padding: 1.5rem;
    border-radius: 8px;
    background: var(--surface, #fff);
    box-shadow: 0 6px 18px rgba(0,0,0,0.06);
    text-align: center;
  }
  .title {
    color: var(--text-900, #0f172a);
    margin-bottom: 0.5rem;
  }
  .desc {
    color: var(--text-600, #475569);
    margin-bottom: 1.25rem;
  }
  .cta-row {
    display:flex;
    gap: 0.75rem;
    justify-content:center;
    margin-top: 1rem;
  }
  .btn {
    padding: 0.6rem 1rem;
    border-radius: 6px;
    text-decoration: none;
    display:inline-block;
    font-weight: 600;
  }
  .btn-primary { background: var(--brand, #2563eb); color: white; }
  .btn-secondary { background: transparent; color: var(--brand, #2563eb); border: 1px solid rgba(37,99,235,0.12); }
</style>

<main class="confirmation">
  <h1 class="title">Submission Confirmed</h1>

  {#if client}
    <p class="desc">Thank you, <strong>{client.name}</strong>. Your response for <strong>{form?.name}</strong> has been submitted and locked.</p>
  {:else}
    <p class="desc">Your response has been submitted and locked.</p>
  {/if}

  <div class="cta-row">
    <a class="btn btn-primary" href="/">Return to Home</a>
    <a class="btn btn-secondary" href="/client_forms" >View Links</a>
  </div>
</main>
