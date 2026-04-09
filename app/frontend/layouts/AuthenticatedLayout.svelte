<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import Toast from "/components/customs/Toast.svelte";
  import { page } from "@inertiajs/svelte";
  import { getOnboardingTutorialKey } from '@/lib/onboarding-tutorials';
  import { getPathname } from "@/lib/utils";

  let { children } = $props();

  type OnboardingTutorialHostComponentType = typeof import('/components/onboarding/OnboardingTutorialHost.svelte').default;

  const sessionId = $derived(($page?.props as Record<string, unknown>)?.session_id as string);

  const currentPath = $derived(getPathname($page?.url));
  const activeTutorialKey = $derived(getOnboardingTutorialKey($page?.url));

  const crmSignals = $derived(($page?.props as any)?.crm_transfer_signals);
  const crmToast = $derived(crmSignals?.toast);
  const showCrmToast = $derived(!!crmToast && !currentPath.startsWith('/crm_transfers'));
  let OnboardingTutorialHostComponent = $state<OnboardingTutorialHostComponentType | null>(null);

  $effect(() => {
    if (!activeTutorialKey) {
      OnboardingTutorialHostComponent = null;
      return;
    }

    let active = true;

    import('/components/onboarding/OnboardingTutorialHost.svelte')
      .then((module) => {
        if (active) {
          OnboardingTutorialHostComponent = module.default;
        }
      })
      .catch((error) => {
        console.error('Failed to load onboarding tutorial host', error);
      });

    return () => {
      active = false;
    };
  });
</script>

<Sidebar.Provider>
  <AppSidebar session_id={sessionId} />
  <main class="min-h-screen w-full bg-muted/40 px-4 py-6 md:px-8">
    <Sidebar.Trigger class="mb-4" />
    {#if showCrmToast}
      <Toast message={crmToast.message} type={crmToast.type} actionHref={crmToast.href} actionLabel="View transfers" />
    {/if}
    {@render children?.()}
  </main>

  {#if OnboardingTutorialHostComponent && activeTutorialKey}
    <OnboardingTutorialHostComponent tutorialKey={activeTutorialKey} />
  {/if}
</Sidebar.Provider>
