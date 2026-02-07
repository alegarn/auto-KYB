<script>
  import Button from '@/components/ui/button/button.svelte';
  import { clients_path, dashboard_path } from '@/routes';
  import { page } from '@inertiajs/svelte'
  const { client, form, access_url, password } = $props();
</script>

<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8 flex items-center justify-center">
  <section class="w-full max-w-3xl rounded-lg border border-border bg-background p-6">
    <h1 class="text-2xl font-semibold text-foreground">Password Reveal</h1>

    {#if $page.flash?.alert}
      <div class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700" role="alert">
        <span>{$page.flash?.alert}</span>
      </div>
    {/if}

    <p class="text-sm text-muted-foreground">Client: <strong class="text-foreground">{client?.name}</strong></p>
    <p class="text-sm text-muted-foreground">Form: <strong class="text-foreground">{form?.name}</strong></p>
    <br>
    <p class="text-foreground">Share the information below with your client securely for them to access the form.</p>
    <p class="text-red-600">Information below are shown only once and cannot be retrieved again.</p>
    <div class="mt-4">
      <div class="text-xs font-medium text-muted-foreground">Access URL <strong class="text-red-600 ">(showed only once)</strong></div>
      <div class="mt-1 break-words">{`${window.location.origin}${access_url}`}</div>
    </div>

    {#if password}
      <div class="mt-4">
        <div class="text-xs font-medium text-muted-foreground">Password to access the form <strong class="text-red-600 ">(showed only once)</strong></div>
        <div class="mt-1 rounded-md border border-border bg-muted/20 p-3 font-mono text-sm">{password}</div>
      </div>
    {/if}

    <div class="mt-6 flex gap-3">
      <Button href={clients_path()} variant="secondary">Back to Clients</Button>
      <Button href={dashboard_path()} variant="default">Back to Dashboard</Button>
    </div>
  </section>
</main>
