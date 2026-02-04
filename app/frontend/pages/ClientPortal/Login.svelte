<script lang="ts">
  import { createEventDispatcher } from 'svelte'
  export let access_token: string

  // callback prop for Svelte 5 compatibility
  export let onLogin: (payload: any) => void = () => {}

  let password = ''

  function submit(e: Event) {
    e.preventDefault()
    onLogin({ password, access_token })
  }
</script>

<form on:submit|preventDefault={submit}>
  <div>
    <label for="password">Password</label>
    <input id="password" aria-label="Password" type="password" bind:value={password} />
  </div>
  <button type="submit">Login</button>
</form>
