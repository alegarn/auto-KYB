<script lang="ts">
  import { client_portal_login_path } from '@/routes'

  const props = $props()
  const access_token = $derived(props.access_token)
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

{#if flashMessage}
  <div class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700" role="alert">
    <span>{flashMessage}</span>
  </div>
{/if}

<form method="post" action={client_portal_login_path(access_token)} onsubmit={submit}>
  <div>
    <label for="password">Password</label>
    <input id="password" name="password" aria-label="Password" type="password" bind:value={password} />
  </div>
  <button type="submit">Login</button>
</form>
