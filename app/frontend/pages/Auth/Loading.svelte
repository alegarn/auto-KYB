<script lang="ts">
  import { router } from '@inertiajs/svelte'

  let { redirect_to, bootstrap_ready } = $props<{ redirect_to: string; bootstrap_ready: boolean }>()

  let navigationStarted = $state(false)
  const renderedAt = Date.now()

  async function continueToDashboard() {
    if (navigationStarted) return

    navigationStarted = true

    const minimumVisibleMs = 250
    const elapsed = Date.now() - renderedAt
    if (elapsed < minimumVisibleMs) {
      await new Promise((resolve) => setTimeout(resolve, minimumVisibleMs - elapsed))
    }

    router.visit(redirect_to, { replace: true })
  }

  $effect(() => {
    if (bootstrap_ready) {
      continueToDashboard()
    }
  })
</script>

<section class="flex min-h-screen items-center justify-center bg-background px-6">
  <div class="flex w-full max-w-sm flex-col items-center gap-4 text-center">
    <div class="h-8 w-8 animate-spin rounded-full border-2 border-muted border-t-foreground" aria-hidden="true"></div>
    <div class="space-y-1">
      <h1 class="text-base font-semibold text-foreground">Preparing your dashboard</h1>
      <p class="text-sm text-muted-foreground">Please wait a moment...</p>
    </div>
  </div>
</section>