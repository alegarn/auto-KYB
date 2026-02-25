<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "/components/ui/button/button.svelte";
  import { root_path, sign_in_path } from "@/routes";
  import { page } from "@inertiajs/svelte";
  import logo from "@/assets/quick_kyb_icon.svg";
  import { onMount } from "svelte";

  let { stripe_publishable_key, stripe_pricing_table_id, customer_email } = $props();

  onMount(() => {
    // Dynamically load the Stripe pricing table script
    const script = document.createElement("script");
    script.src = "https://js.stripe.com/v3/pricing-table.js";
    script.async = true;
    document.head.appendChild(script);

    return () => {
      // Cleanup if needed
      if (document.head.contains(script)) {
        document.head.removeChild(script);
      }
    };
  });
</script>

{#if $page?.flash?.alert}
  <div
    class="mb-4 rounded-(--radius) bg-red-100 p-4 text-sm text-red-800 dark:bg-red-200"
    role="alert"
  >
    {$page?.flash?.alert}
  </div>
{/if}

<section
  class="flex min-h-screen bg-zinc-50 px-4 py-16 md:py-32 dark:bg-transparent"
>
  <div class="m-auto w-full max-w-4xl">
    <div class="text-center mb-8">
      <Button href={root_path()} aria-label="go home" variant="ghost">
        <img
          src={logo}
          alt="Logo"
          class="h-12 w-auto rounded-sm mx-auto"
          width="48"
          height="48"
        />
      </Button>
      <h1 class="text-title mb-2 mt-4 text-3xl font-bold">
        Choose your plan before creating your account
      </h1>
      <p class="text-lg text-muted-foreground">Select a plan to create your Quick KYB account</p>
    </div>

    {#if stripe_publishable_key && stripe_pricing_table_id}
      <div class="bg-card rounded-[calc(var(--radius)+.125rem)] border p-4 shadow-md dark:[--color-muted:var(--color-zinc-900)]">
        <stripe-pricing-table 
          pricing-table-id={stripe_pricing_table_id}
          publishable-key={stripe_publishable_key}
          customer-email={customer_email || undefined}
        >
        </stripe-pricing-table>
      </div>
    {:else}
      <div class="bg-red-50 border border-red-200 text-red-800 p-4 rounded-md text-center">
        Stripe configuration is missing. Please check your environment variables.
      </div>
    {/if}

    <div class="mt-8 text-center">
      <p class="text-accent-foreground text-sm">
        Already have an account?
        <Button href={sign_in_path()} variant="link" class="px-2">Sign in</Button>
      </p>
    </div>
  </div>
</section>
