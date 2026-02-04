<script>
  import { page } from '@inertiajs/svelte'
  const { client, form, access_url, password } = $props();
</script>

<main class="container">
  <h1>Password Reveal</h1>

  {#if $page.flash?.alert}
    <div class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700" role="alert">
      <span>{$page.flash?.alert}</span>
    </div>
  {/if}

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
  {/if}
</main>
