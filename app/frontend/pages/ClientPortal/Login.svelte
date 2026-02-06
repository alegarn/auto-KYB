<script lang="ts">
  import { client_portal_login_path } from '@/routes'

  const props = $props()
  const access_token = $derived(props.access_token)
  const portal_status = $derived(props.portal_status)
  const injectedOnLogin = $derived(props.onLogin)
  const hasInjectedHandler = $derived(typeof injectedOnLogin === 'function')

  let password = $state('')
  let flashMessage = $state<string | null>(null)

  async function submit(e: SubmitEvent) {
    if (hasInjectedHandler) {
      e.preventDefault()
      injectedOnLogin?.({ password, access_token })
      return
    }

    e.preventDefault()
    flashMessage = null

    const response = await fetch(client_portal_login_path(access_token), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      credentials: 'same-origin',
      body: JSON.stringify({ password }),
    })

    if (response.status === 429) {
      const data = await response.json().catch(() => null)
      flashMessage = data?.error || 'Too many requests. Please try again later.'
      return
    }

    if (response.status === 410) {
      flashMessage = 'This portal is no longer available.'
      return
    }

    if (response.status === 401) {
      flashMessage = 'Invalid password. Please try again.'
      return
    }

    if (response.redirected) {
      window.location.href = response.url
      return
    }

    if (!response.ok) {
      flashMessage = 'Unable to login right now. Please try again.'
    }
  }
</script>

<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
  <section class="max-w-md mx-auto rounded-lg border border-border bg-background p-6">
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
          <input id="password" name="password" aria-label="Password" type="password" bind:value={password} class="mt-1 block w-full rounded-md border border-input bg-input p-2" />
        </div>
        <div>
          <button type="submit" class="inline-flex w-full items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">Login</button>
        </div>
      </form>
    {/if}
  </section>
</main>
