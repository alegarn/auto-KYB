<script lang="ts">
  //import Heroheader from '@/components/ui/heroheader/heroheader.svelte';
  import Button from "/components/ui/button/button.svelte";
  import { page } from '@inertiajs/svelte'
  import { sign_in_path, sign_up_path } from '@/routes';

  // Lazy load heavy components
  const Heroheader = import('/components/ui/heroheader/heroheader.svelte');
  const Features = import('/components/customs/features.svelte');
  const Pricing = import('/components/customs/pricing.svelte');
  const Footer = import("/components/ui/footer/footer.svelte");

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
</script>

<div>
  {#await Heroheader then module}
    <module.default 
      sign_in_path={sign_in_path} 
      sign_up_path={sign_up_path} 
      user={$page?.props?.user} 
    />
  {/await}
  <main class="overflow-hidden">
    <div
      class="absolute isolate hidden opacity-65 contain-strict lg:block"
    >
      <div
        class="w-140 h-320 -translate-y-87.5 absolute left-0 top-0 -rotate-45 rounded-full bg-[radial-gradient(68.54%_68.72%_at_55.02%_31.46%,hsla(0,0%,85%,.08)_0,hsla(0,0%,55%,.02)_50%,hsla(0,0%,45%,0)_80%)]"
      ></div>
      <div
        class="h-320 absolute left-0 top-0 w-60 -rotate-45 rounded-full bg-[radial-gradient(50%_50%_at_50%_50%,hsla(0,0%,85%,.06)_0,hsla(0,0%,45%,.02)_80%,transparent_100%)] [translate:5%_-50%]"
      ></div>
      <div
        class="h-320 -translate-y-87.5 absolute left-0 top-0 w-60 -rotate-45 bg-[radial-gradient(50%_50%_at_50%_50%,hsla(0,0%,85%,.04)_0,hsla(0,0%,45%,.02)_80%,transparent_100%)]"
      ></div>
    </div>
    <section>
      <div class="relative pt-24 md:pt-36">
        <div
          class="absolute inset-0 -z-10 size-full [background:radial-gradient(125%_125%_at_50%_100%,transparent_0%,var(--color-background)_75%)]"
        ></div>
        <div class="mx-auto max-w-7xl px-6">
          <div class="text-center mx-auto lg:mx-auto lg:mt-0 pb-20 md:pb-32 lg:pb-40">
            <h1
              class="mt-8 text-balance text-6xl md:text-7xl lg:mt-16 xl:text-[5.25rem]"
            >
              Quick KYB
            </h1>
            <p class="mx-auto mt-8 max-w-2xl text-balance text-lg">
              Cut friction, not compliance — seamless KYC/KYB that keeps payments moving.
            </p>

            <div
              class="mt-12 flex flex-col items-center justify-center gap-2 md:flex-row"
            >
              <div
                class="bg-foreground/10 border p-0.5"
                style="border-radius: calc(0.5rem + 0.125rem + 4px);"
              >
                <Button
                  href={sign_up_path()}
                  size="lg"
                  class="rounded-xl px-5 text-base"
                >
                  <span class="text-nowrap">Start Onboarding</span>
                </Button>
              </div>
              <Button size="lg" variant="ghost" class="rounded-xl px-5" >
                Request a demo
              </Button>
            </div>
          </div>
        </div>

        <!-- Image section with reserved space to prevent layout shift -->
        <div
          class="relative -mr-56 mt-8 overflow-hidden px-2 sm:mr-0 sm:mt-12 md:mt-20"
        >
          <div
            class="bg-linear-to-b to-background absolute inset-0 z-10 from-transparent from-35%"
          ></div>
          <div
            class="inset-shadow-2xs ring-background dark:inset-shadow-white/20 bg-background relative mx-auto max-w-6xl overflow-hidden rounded-2xl border p-4 shadow-lg shadow-zinc-950/15"
          >
            <!-- Reserved space container with aspect ratio to prevent layout shift -->
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
                <!-- Skeleton placeholder while image loads -->
                <div class="absolute inset-0 flex items-center justify-center rounded-2xl bg-muted/30 animate-pulse">
                  <svg class="w-12 h-12 text-muted-foreground/30" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
              {/if}
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>
  
  <!-- Lazy loaded components with fallback -->
  {#await Features then module}
    <module.default />
  {/await}
  
  {#await Pricing then module}
    <module.default />
  {/await}
  
  {#await Footer then module}
    <module.default />
  {/await}
</div>