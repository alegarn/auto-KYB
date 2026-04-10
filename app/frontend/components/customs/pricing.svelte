<script lang="ts">
  import Button from "/components/ui/button/button.svelte";
  import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
    CardFooter,
  } from "/components/ui/card";
  import Check from "@lucide/svelte/icons/check";
  import { router } from "@inertiajs/svelte";
  import { sign_up_path } from '@/routes';

  let pricingList = {
    basic: [
      "Personalized KYC/KYB form builder",
      "Unique registration link for leads",
      "Required vs validated field flags",
      "Partial updates allowed",
      "Provider notified on validation",
      "Raw data export (JSON / CSV)",
    ],
    pro: [
      "Everything in Basic",
      "CRM exports: HubSpot, Salesforce",
    ],
    premium: [
      "Everything in Pro",
      "Client pre-onboard company research",
      "Client company KYB autocomplete on form",
    ],
  };

  const { customer_email = undefined } = $props();

  const handleSubscribe = async (plan: string) => {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content");
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
      };
      if (csrfToken) {
        headers["X-CSRF-Token"] = csrfToken;
      }

      const response = await fetch("/checkout_sessions", {
        method: "POST",
        headers,
        body: JSON.stringify({ plan, email: customer_email }),
      });
      const data = await response.json();
      if (data.url) {
        window.location.href = data.url;
      }
    } catch (e) {
      console.error("Failed to create checkout session", e);
      router.visit(sign_up_path());
    }
  };
</script>

<section id="pricing" class="py-16 md:py-32">
  <div class="mx-auto max-w-6xl px-6">
    <div class="mx-auto max-w-2xl space-y-6 text-center">
      <h1 class="text-center text-4xl font-semibold lg:text-5xl">
        Pricing that Scales with You
      </h1>
      <p class="text-muted-foreground">
        Streamline your client onboarding with customizable KYC/KYB forms, secure data collection, and seamless CRM integrations.
      </p>
    </div>

    <div
      class="mt-8 grid gap-6 [--color-card:var(--color-muted)] *:border-none *:shadow-none md:mt-20 md:grid-cols-3 dark:[--color-muted:var(--color-zinc-900)]"
    >
      <Card class="flex flex-col">
        <CardHeader>
          <CardTitle class="font-medium">Basic</CardTitle>
          <span class="my-3 block text-2xl font-semibold">$99 / mo</span>
          <CardDescription class="text-sm">Per editor</CardDescription>
        </CardHeader>

        <CardContent class="space-y-4">
          <hr class="border-dashed" />

          <ul class="list-outside space-y-3 text-sm">
            {#each pricingList.basic as item}
              <li class="flex items-center gap-2">
                <Check class="size-3" />
                {item}
              </li>
            {/each}
          </ul>
        </CardContent>

        <CardFooter class="mt-auto">
          <Button variant="outline" class="w-full" onclick={() => handleSubscribe('basic')}>
            Get Started
          </Button>
        </CardFooter>
      </Card>

      <Card class="relative flex flex-col">
        <div class="flex flex-col flex-1">
          <CardHeader>
            <CardTitle class="font-medium">Pro</CardTitle>
            <span class="my-3 block text-2xl font-semibold">$499 / mo</span>
            <CardDescription class="text-sm">Per editor</CardDescription>
          </CardHeader>

          <CardContent class="space-y-4">
            <hr class="border-dashed" />
            <ul class="list-outside space-y-3 text-sm">
              {#each pricingList.pro as item}
                <li class="flex items-center gap-2">
                  <Check class="size-3" />
                  {item}
                </li>
              {/each}
            </ul>
          </CardContent>

          <CardFooter class="mt-auto">
            <Button class="w-full" onclick={() => handleSubscribe('pro')}>
              Get Started
            </Button>
          </CardFooter>
        </div>
      </Card>

      <Card class="relative flex flex-col opacity-80">
        <span
          class="bg-muted text-muted-foreground absolute inset-x-0 -top-3 mx-auto flex h-6 w-fit items-center rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset ring-white/20 ring-offset-1 ring-offset-gray-950/5"
          >Coming Soon</span
        >

        <CardHeader>
          <CardTitle class="font-medium">Premium</CardTitle>
          <span class="my-3 block text-2xl font-semibold">$999 / mo</span>
          <CardDescription class="text-sm">Per editor</CardDescription>
        </CardHeader>

        <CardContent class="space-y-4">
          <hr class="border-dashed" />

          <ul class="list-outside space-y-3 text-sm">
            {#each pricingList.premium as item}
              <li class="flex items-center gap-2">
                <Check class="size-3" />
                {item}
              </li>
            {/each}
          </ul>
        </CardContent>

        <CardFooter class="mt-auto">
          <Button variant="outline" class="w-full" disabled>
            Coming Soon
          </Button>
        </CardFooter>
      </Card>
    </div>

    <div class="mt-8 md:mt-12">
      <Card class="flex flex-col md:flex-row items-center justify-between p-6 md:p-8">
        <div class="space-y-2 text-center md:text-left">
          <h3 class="text-2xl font-semibold">Custom</h3>
          <p class="text-muted-foreground">Custom CRM mapping & advanced integration support</p>
        </div>
        <div class="mt-6 md:mt-0">
          <Button variant="outline" size="lg">Contact Sales</Button>
        </div>
      </Card>
    </div>
  </div>
</section>
