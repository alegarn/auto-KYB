<script>
  const { client, form, access_url, password } = $props();
</script>

<main class="container">
  <h1>Password Reveal</h1>
  <p>Client: {client?.name}</p>
  <p>Form: {form?.name}</p>

  <div>
    <div class="field-label">Access URL</div>
    <div><a href={access_url}>{access_url}</a></div>
  </div>

  {#if password}
    <div>
      <div class="field-label">One-time password (showed once)</div>
      <div class="password">{password}</div>
    </div>
  {:else}
    <div class="expired">Password no longer available or expired.</div>
  {/if}
</main>
