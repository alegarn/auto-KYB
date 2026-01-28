<script>
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

  let pricingList = {
    basic: [
      "Personalized KYC/KYB form builder",
      "Unique registration link for leads",
      "Required vs validated field flags",
      "Partial updates allowed",
      "Provider notified on validation",
      "Raw data export (text / CSV)",
    ],
    pro: [
      "Everything in Basic",
      "CRM exports: HubSpot, Salesforce, Zoho",
      "Field-level validation by approvers",
      "Scheduled and on-demand CSV exports",
    ],
    premium: [
      "Everything in Pro",
      "Admin pre-onboard company research + KYB autocomplete",
      "Client-side company autocomplete during signup",
      "Autocompletion finalised on client validation",
      "Custom CRM mapping & advanced integration support",
    ],
  };
</script>

<section class="py-16 md:py-32">
  <div class="mx-auto max-w-6xl px-6">
    <div class="mx-auto max-w-2xl space-y-6 text-center">
      <h1 class="text-center text-4xl font-semibold lg:text-5xl">
        Pricing that Scales with You
      </h1>
      <p>
        Gemini is evolving to be more than just the models. It supports an
        entire to the APIs and platforms helping developers and businesses
        innovate.
      </p>
    </div>

    <div
      class="mt-8 grid gap-6 [--color-card:var(--color-muted)] *:border-none *:shadow-none md:mt-20 md:grid-cols-3 dark:[--color-muted:var(--color-zinc-900)]"
    >
      <Card class="flex flex-col">
        <CardHeader>
          <CardTitle class="font-medium">Basic</CardTitle>
          <span class="my-3 block text-2xl font-semibold">$9 / mo</span>
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
          <Button variant="outline" class="w-full">
            Get Started
          </Button>
        </CardFooter>
      </Card>

      <Card class="relative flex flex-col">
        <span
          class="bg-linear-to-br/increasing absolute inset-x-0 -top-3 mx-auto flex h-6 w-fit items-center rounded-full from-purple-400 to-amber-300 px-3 py-1 text-xs font-medium text-amber-950 ring-1 ring-inset ring-white/20 ring-offset-1 ring-offset-gray-950/5"
          >Popular</span
        >

        <div class="flex flex-col flex-1">
          <CardHeader>
            <CardTitle class="font-medium">Pro</CardTitle>
            <span class="my-3 block text-2xl font-semibold">$29 / mo</span>
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
            <Button class="w-full">
              Get Started
            </Button>
          </CardFooter>
        </div>
      </Card>

      <Card class="flex flex-col">
        <CardHeader>
          <CardTitle class="font-medium">Premium</CardTitle>
          <span class="my-3 block text-2xl font-semibold">$49 / mo</span>
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
          <Button variant="outline" class="w-full">
            Get Started
          </Button>
        </CardFooter>
      </Card>
    </div>
  </div>
</section>
