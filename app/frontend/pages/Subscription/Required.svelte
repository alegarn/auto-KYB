<script lang="ts">
  import { sign_up_path, root_path } from '@/routes'

  const props = $props()
  const user = $derived(props.user)
</script>

<main class="min-h-screen flex items-center justify-center p-6 bg-slate-50">
  <section class="max-w-2xl w-full bg-white rounded-lg shadow-md p-8">
    <h1 class="text-3xl font-bold mb-4">Subscription required</h1>
    <p class="mb-6 text-lg text-slate-700">To continue using advanced features of QuickKYB (multi-client management, exports, premium forms), an active subscription is required. Subscribing helps us maintain the service and deliver improvements.</p>

    <ul class="mb-6 list-disc list-inside text-slate-600">
      <li>Unlimited client exports and CSV downloads</li>
      <li>Advanced form branching and conditional logic</li>
      <li>Priority support and early access to new features</li>
    </ul>

    <div class="flex items-center gap-4">
      <a href={sign_up_path()} class="inline-flex items-center rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">Start subscription</a>
      <a href={root_path()} class="text-sm text-slate-500">Return to public home</a>
    </div>
  </section>
</main>
