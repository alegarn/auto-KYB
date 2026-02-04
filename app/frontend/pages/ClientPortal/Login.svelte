<script lang="ts">
  import { client_portal_login_path } from '@/routes'

  const props = $props()
  const access_token = $derived(props.access_token)
  const injectedOnLogin = $derived(props.onLogin)
  const hasInjectedHandler = $derived(typeof injectedOnLogin === 'function')

  let password = $state('')

  function submit(e: SubmitEvent) {
    if (hasInjectedHandler) {
      e.preventDefault()
      injectedOnLogin?.({ password, access_token })
    }
  }
</script>

<form method="post" action={client_portal_login_path(access_token)} onsubmit={submit}>
  <div>
    <label for="password">Password</label>
    <input id="password" name="password" aria-label="Password" type="password" bind:value={password} />
  </div>
  <button type="submit">Login</button>
</form>
