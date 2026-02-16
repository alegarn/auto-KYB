<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { client_portal_login_path } from '@/routes'

  const props = $props()
  const access_token = $derived(props.access_token)
  const portal_status = $derived(props.portal_status)
  const incomingFlash = $derived<{ type: 'alert' | 'notice'; message?: string } | null>(props.flash_message || null)
  const injectedOnLogin = $derived(props.onLogin)
  const hasInjectedHandler = $derived(typeof injectedOnLogin === 'function')

  const form = useForm({ password: '' })
  const flashMessage = $derived(incomingFlash?.message ?? null)

  function submit(e: SubmitEvent) {
    if (hasInjectedHandler) {
      e.preventDefault()
      injectedOnLogin?.({ password: $form.password, access_token })
      return
    }

    e.preventDefault()
    $form.post(client_portal_login_path(access_token), {
      preserveState: true,
      preserveScroll: true,
    })
  }
</script>

<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8 flex items-center justify-center">
  <section class="w-full max-w-md rounded-lg border border-border bg-background p-6">
    {#if flashMessage}
      <div class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700" role="alert">
        <span>{flashMessage}</span>
      </div>
    {/if}

    {#if portal_status === 'gone'}
      <div class="rounded-md border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900" role="status">
        <p>This portal is no longer available.</p>
      </div>
    {:else}
      <form method="post" action={client_portal_login_path(access_token)} onsubmit={submit} class="space-y-4">
        <div>
          <label for="password" class="block text-sm font-medium text-muted-foreground">Password</label>
          <input id="password" name="password" aria-label="Password" type="password" bind:value={$form.password} class="mt-1 block w-full rounded-md border border-input bg-input p-2" />
        </div>
        <div>
          <button type="submit" disabled={$form.processing} class="inline-flex w-full items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50">Login</button>
        </div>
      </form>
    {/if}
  </section>
</main>
