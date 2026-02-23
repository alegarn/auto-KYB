<script lang="ts">
  import { page } from '@inertiajs/svelte';
  import { sign_up_path } from '@/routes';
  import Button from "/components/ui/button/button.svelte";
  import ArrowRight from "@lucide/svelte/icons/arrow-right";

  // Lazy load the dashboard image
  let dashboardImage = $state<string | null>(null);
  let imageLoaded = $state(false);

  $effect(() => {
    // Defer image loading after initial render
    const loadImage = async () => {
      const module = await import('/assets/dashboard.png');
      dashboardImage = module.default;
    };
    
    // Use requestIdleCallback or setTimeout to defer loading
    if (typeof requestIdleCallback !== 'undefined') {
      requestIdleCallback(() => loadImage());
    } else {
      setTimeout(() => loadImage(), 100);
    }
  });

  const steps = [
    {
      title: "1. Create your Form",
      description: "Use the form builder to create or update a form. Give your clients clear indications on where to find the required information using the content field. You can also provide URLs to document templates. Mark essential fields as 'required' so clients must complete them before submitting.",
      icon: "📝"
    },
    {
      title: "2. Add a Client",
      description: "Add a new client with their information (name, company, company ID, address, etc.). Once added, the system will generate a unique secure link and password combination for this client.",
      icon: "👤"
    },
    {
      title: "3. Share Access",
      description: "Send the generated secure link and password to your client through your preferred communication channel.",
      icon: "🔗"
    },
    {
      title: "4. Client Login",
      description: "The client follows the secure link and logs into their dedicated portal using the provided password.",
      icon: "🔐"
    },
    {
      title: "5. Data Collection",
      description: "The client fills out the form and uploads the required files. They can do this in one go or save their progress and return later.",
      icon: "📄"
    },
    {
      title: "6. Status Tracking",
      description: "Monitor the client's progress in real-time. Their status automatically updates from 'Linked' to 'Active' as they work, and finally to 'Validated' once they submit the completed form.",
      icon: "📊"
    },
    {
      title: "7. Export Data",
      description: "Once the client submits the form and their status turns to 'Validated', you can easily export all their submitted data in CSV or JSON format directly from their client page.",
      icon: "⬇️"
    }
  ];
</script>

<svelte:head>
  <title>Quickstart Guide - Quick KYB</title>
  <meta name="description" content="Learn how to get started with Quick KYB in 7 easy steps." />
</svelte:head>

<div>
  <!-- Background effects -->
    <div class="absolute isolate hidden opacity-65 contain-strict lg:block pointer-events-none">
      <div class="w-140 h-320 -translate-y-87.5 absolute left-0 top-0 -rotate-45 rounded-full bg-[radial-gradient(68.54%_68.72%_at_55.02%_31.46%,hsla(0,0%,85%,.08)_0,hsla(0,0%,55%,.02)_50%,hsla(0,0%,45%,0)_80%)]"></div>
      <div class="h-320 absolute left-0 top-0 w-60 -rotate-45 rounded-full bg-[radial-gradient(50%_50%_at_50%_50%,hsla(0,0%,85%,.06)_0,hsla(0,0%,45%,.02)_80%,transparent_100%)] [translate:5%_-50%]"></div>
    </div>

    <section class="relative pt-24 pb-16 md:pt-32 md:pb-24">
      <div class="mx-auto max-w-4xl px-6">
        <div class="text-center mb-16">
          <h1 class="text-4xl md:text-5xl font-bold tracking-tight mb-6">
            Quickstart Guide
          </h1>
          <p class="text-xl text-muted-foreground max-w-2xl mx-auto">
            Master the Quick KYB workflow in 7 simple steps. From creating your first form to exporting client data.
          </p>
        </div>

        <!-- Image section with reserved space to prevent layout shift -->
        <div class="relative mb-20 overflow-hidden px-2">
          <div class="inset-shadow-2xs ring-background dark:inset-shadow-white/20 bg-background relative mx-auto max-w-5xl overflow-hidden rounded-2xl border p-4 shadow-lg shadow-zinc-950/15">
            <div class="aspect-15/8 relative rounded-2xl bg-muted/50">
              {#if dashboardImage}
                <img
                  class="bg-background aspect-15/8 absolute inset-0 hidden rounded-2xl transition-opacity duration-300 dark:block {imageLoaded ? 'opacity-100' : 'opacity-0'}"
                  src={dashboardImage}
                  alt="app screen"
                  width="2700"
                  height="1440"
                  loading="lazy"
                  decoding="async"
                  onload={() => imageLoaded = true}
                />
                <img
                  class="z-2 border-border/25 aspect-15/8 absolute inset-0 rounded-2xl border transition-opacity duration-300 dark:hidden {imageLoaded ? 'opacity-100' : 'opacity-0'}"
                  src={dashboardImage}
                  alt="app screen"
                  width="2700"
                  height="1440"
                  loading="lazy"
                  decoding="async"
                  onload={() => imageLoaded = true}
                />
              {:else}
                <div class="absolute inset-0 flex items-center justify-center rounded-2xl bg-muted/30 animate-pulse">
                  <svg class="w-12 h-12 text-muted-foreground/30" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
              {/if}
            </div>
          </div>
        </div>

        <div class="space-y-8 relative before:absolute before:inset-0 before:ml-5 before:-translate-x-px md:before:mx-auto md:before:translate-x-0 before:h-full before:w-0.5 before:bg-gradient-to-b before:from-transparent before:via-border before:to-transparent">
          {#each steps as step, index}
            <div class="relative flex items-center justify-between md:justify-normal md:odd:flex-row-reverse group is-active">
              <!-- Icon -->
              <div class="flex items-center justify-center w-10 h-10 rounded-full border-4 border-background bg-muted text-xl shadow shrink-0 md:order-1 md:group-odd:-translate-x-1/2 md:group-even:translate-x-1/2 z-10">
                {step.icon}
              </div>
              
              <!-- Card -->
              <div class="w-[calc(100%-4rem)] md:w-[calc(50%-2.5rem)] p-4 rounded-xl border bg-card text-card-foreground shadow-sm transition-all hover:shadow-md">
                <div class="flex flex-col gap-2">
                  <h3 class="font-semibold text-lg flex items-center gap-2">
                    {step.title}
                  </h3>
                  <p class="text-muted-foreground leading-relaxed">
                    {step.description}
                  </p>
                </div>
              </div>
            </div>
          {/each}
        </div>

        <div class="mt-20 text-center">
          <div class="bg-foreground/10 border p-0.5 inline-block rounded-2xl">
            <Button
              href={sign_up_path()}
              size="lg"
              class="rounded-xl px-8 text-base h-14"
            >
              <span class="text-nowrap">Start Onboarding Now</span>
              <ArrowRight class="ml-2 h-5 w-5" />
            </Button>
          </div>
        </div>
      </div>
    </section>
</div>
