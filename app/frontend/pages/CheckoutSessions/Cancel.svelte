<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { checkout_sessions_path } from '@/routes'

  const props = $props()
  const user = $derived(props.user)

  const form = useForm({})

  function retry() {
    // Trigger POST to create a new checkout session and redirect
    $form.post(checkout_sessions_path(), {
      preserveState: true,
      onSuccess: (page) => {
        // backend returns { url }
        const url = page?.props?.url
        // ? ok to let it with 1 if not 2
        if (typeof url === 'string' && typeof window !== 'undefined' && window.location) {
          window.location.href = url
        }
      }
    })
  }
</script>

<main class="min-h-screen flex items-center justify-center p-6">
  <section class="max-w-lg w-full text-center">
    <h1 class="text-2xl font-semibold mb-4">Payment cancelled</h1>
    <p class="mb-4">Your payment was cancelled. You can retry to complete your subscription.</p>
    <div>
      <button onclick={retry} class="inline-flex items-center rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">Retry payment</button>
    </div>
  </section>
</main>
