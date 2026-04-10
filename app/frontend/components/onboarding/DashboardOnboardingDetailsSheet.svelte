<script lang="ts">
  import { Button } from '/components/ui/button';
  import * as Sheet from '/components/ui/sheet';
  import { getDashboardOnboardingStepContent, getDashboardOnboardingVariantContent, getGuides } from '@/lib/dashboard-onboarding-content';
  import type { DashboardOnboarding, GuideKey } from '@/types/dashboard-onboarding';
  import { router } from '@inertiajs/svelte';

  let {
    onboarding,
    open = $bindable(false)
  }: {
    onboarding: DashboardOnboarding;
    open?: boolean;
  } = $props();

  let activeTab: 'steps' | 'explore' = $state('steps');
  let selectedGuideKey: GuideKey | null = $state(null);

  const variantContent = $derived(getDashboardOnboardingVariantContent(onboarding.variant));
  const stepsWithContent = $derived(
    onboarding.quick_steps.map((step) => ({
      ...step,
      content: getDashboardOnboardingStepContent(step.key)
    }))
  );
  const guides = $derived(getGuides(onboarding));
  const selectedGuide = $derived(guides.find((guide) => guide.key === selectedGuideKey) ?? null);

  function statusClasses(complete: boolean) {
    return complete
      ? 'bg-emerald-100 text-emerald-700'
      : 'bg-slate-100 text-slate-600';
  }

  function openGuide(key: GuideKey) {
    selectedGuideKey = key;
    if (!onboarding.guides_seen?.[key]) {
      router.patch('/onboarding/guide_seen', { guide_key: key }, { preserveScroll: true, preserveState: true });
    }
  }

  function backToGuides() {
    selectedGuideKey = null;
  }

  function tabClasses(tab: 'steps' | 'explore') {
    return tab === activeTab
      ? 'border-b-2 border-primary text-primary font-medium'
      : 'text-muted-foreground hover:text-foreground';
  }
</script>

<Sheet.Root bind:open onOpenChange={() => { selectedGuideKey = null; activeTab = 'steps'; }}>
  <Sheet.Content side="right" class="w-full sm:max-w-xl p-6">
    <Sheet.Header>
      <Sheet.Title>{variantContent.detailsTitle}</Sheet.Title>
      <Sheet.Description>{variantContent.detailsDescription}</Sheet.Description>
    </Sheet.Header>

    <!-- Tab navigation -->
    <div class="mt-4 flex gap-4 border-b border-border">
      <button
        class={`pb-2 text-sm transition-colors ${tabClasses('steps')}`}
        onclick={() => { activeTab = 'steps'; selectedGuideKey = null; }}
      >
        Quick Steps
      </button>
      <button
        class={`pb-2 text-sm transition-colors ${tabClasses('explore')}`}
        onclick={() => { activeTab = 'explore'; selectedGuideKey = null; }}
      >
        Explore
      </button>
    </div>

    <div class="mt-4 space-y-4 overflow-y-auto pr-1" style="max-height: calc(100vh - 14rem);">
      {#if activeTab === 'steps'}
        <!-- Quick Steps tab (existing) -->
        {#each stepsWithContent as step}
          <section class="rounded-lg border border-border bg-background p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <h3 class="font-medium text-foreground">{step.content.detailsTitle}</h3>
                <p class="mt-1 text-sm text-muted-foreground">{step.content.detailsBody}</p>
              </div>
              <span class={`shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold ${statusClasses(step.complete)}`}>
                {step.complete ? 'Complete' : 'Pending'}
              </span>
            </div>

            {#if step.href}
              <div class="mt-4">
                <Button href={step.href} size="sm" variant={step.complete ? 'secondary' : 'default'}>
                  {step.content.ctaLabel}
                </Button>
              </div>
            {/if}
          </section>
        {/each}
      {:else if selectedGuide}
        <!-- Guide drill-down -->
        <div>
          <button
            class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground transition-colors"
            onclick={backToGuides}
          >
            ← Back to guides
          </button>
          <h3 class="text-lg font-semibold text-foreground">
            {selectedGuide.icon} {selectedGuide.title}
          </h3>
          <p class="mt-1 text-sm text-muted-foreground">{selectedGuide.description}</p>

          {#if selectedGuide.practice.length > 0}
            <div class="mt-5 space-y-3">
              <div class="rounded-lg border border-primary/20 bg-primary/5 p-4">
                <h4 class="text-sm font-semibold text-foreground">Practice in the app</h4>
                <p class="mt-1 text-sm text-muted-foreground">
                  Each mini tutorial opens on the real screen, highlights the exact control, and can be closed instantly.
                </p>
              </div>

              {#each selectedGuide.practice as practice}
                <section class="rounded-lg border border-border bg-background p-4">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <h4 class="text-sm font-medium text-foreground">{practice.title}</h4>
                      <p class="mt-1 text-sm text-muted-foreground">{practice.description}</p>
                      {#if practice.unavailableReason}
                        <p class="mt-2 text-xs text-muted-foreground">{practice.unavailableReason}</p>
                      {/if}
                    </div>

                    <Button href={practice.href ?? undefined} size="sm" variant="default" disabled={!practice.href}>
                      {practice.href ? practice.ctaLabel : 'Unavailable'}
                    </Button>
                  </div>
                </section>
              {/each}
            </div>
          {/if}

          <div class="mt-4 space-y-3">
            <div>
              <h4 class="text-sm font-semibold text-foreground">What to look for</h4>
            </div>
            {#each selectedGuide.tips as tip}
              <div class="rounded-lg border border-border bg-muted/40 p-3">
                <h4 class="text-sm font-medium text-foreground">{tip.title}</h4>
                <p class="mt-1 text-sm text-muted-foreground">{tip.body}</p>
                {#if tip.href}
                  <div class="mt-2">
                    <Button href={tip.href} size="sm" variant="outline">
                      Open →
                    </Button>
                  </div>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {:else}
        <!-- Explore tab: guide cards -->
        {#each guides as guide}
          <button
            class="w-full text-left rounded-lg border border-border bg-background p-4 hover:bg-muted/50 transition-colors"
            onclick={() => openGuide(guide.key)}
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <h3 class="font-medium text-foreground">
                  {guide.icon} {guide.title}
                </h3>
                <p class="mt-1 text-sm text-muted-foreground">{guide.description}</p>
                <span class="mt-2 inline-block text-xs text-muted-foreground">
                  {guide.practice.length} mini tutorial{guide.practice.length === 1 ? '' : 's'} • {guide.tips.length} tips
                </span>
              </div>
              {#if onboarding.guides_seen?.[guide.key]}
                <span class="shrink-0 rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-semibold text-emerald-700">
                  Seen
                </span>
              {/if}
            </div>
          </button>
        {/each}
      {/if}
    </div>
  </Sheet.Content>
</Sheet.Root>