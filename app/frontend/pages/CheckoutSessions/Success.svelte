<script lang="ts">
  import { onMount } from 'svelte'
  const props = $props()
  const user = $derived(props.user)

  onMount(() => {
    setTimeout(() => {
      window.location.href = '/dashboard'
    }, 3000)
  })
</script>

<main class="min-h-screen flex items-center justify-center p-6">
  <section class="max-w-lg w-full text-center">
    <h1 class="text-2xl font-semibold mb-4">Thank you</h1>
    <p class="mb-4">Your subscription is active. Redirecting to your dashboard...</p>
    <p class="text-sm text-muted-foreground">If you are not redirected, <a href="/dashboard" class="text-primary underline">click here</a>.</p>
  </section>
</main>
