<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import { Button } from '/components/ui/button';
  import * as Card from '/components/ui/card';
  import DashboardOnboardingDetailsSheet from '/components/onboarding/DashboardOnboardingDetailsSheet.svelte';
  import { getDashboardOnboardingStepContent, getDashboardOnboardingVariantContent } from '@/lib/dashboard-onboarding-content';
  import type { DashboardOnboarding } from '@/types/dashboard-onboarding';

  let { onboarding }: { onboarding: DashboardOnboarding } = $props();

  let detailsOpen = $state(false);
  let dismissedLocally = $state(false);
  let detailsSeenSubmitted = $state(false);

  const variantContent = $derived(getDashboardOnboardingVariantContent(onboarding.variant));
  const stepsWithContent = $derived(
    onboarding.quick_steps.map((step) => ({
      ...step,
      content: getDashboardOnboardingStepContent(step.key)
    }))
  );
  const remainingStepsCount = $derived(onboarding.quick_steps.filter((step) => !step.complete).length);
  const detailsSeen = $derived(onboarding.detailed_view_seen || detailsSeenSubmitted);

  $effect(() => {
    if (onboarding.detailed_view_seen) {
      detailsSeenSubmitted = true;
    }
  });

  function dismissOnboarding() {
    if (!onboarding.can_dismiss || dismissedLocally) return;

    dismissedLocally = true;
    router.patch('/onboarding/dismiss', {}, {
      preserveScroll: true,
      preserveState: true,
      onError: () => {
        dismissedLocally = false;
      }
    });
  }

  function openDetails() {
    detailsOpen = true;

    if (detailsSeen) return;

    detailsSeenSubmitted = true;
    router.patch('/onboarding/details_seen', {}, {
      preserveScroll: true,
      preserveState: true,
      onError: () => {
        detailsSeenSubmitted = false;
      }
    });
  }

  function statusClasses(complete: boolean) {
    return complete
      ? 'bg-emerald-100 text-emerald-700'
      : 'bg-slate-100 text-slate-600';
  }
</script>

{#if !dismissedLocally}
  <Card.Root>
    <Card.Header class="gap-4 lg:flex-row lg:items-start lg:justify-between">
      <div>
        <p class="text-xs font-medium uppercase tracking-[0.2em] text-muted-foreground">{variantContent.eyebrow}</p>
        <Card.Title class="mt-2">{variantContent.title}</Card.Title>
        <Card.Description class="mt-1">{variantContent.description}</Card.Description>
      </div>

      <div class="flex items-start gap-4 lg:justify-end">
        <div class="text-right">
          <p class="text-2xl font-semibold text-foreground">{onboarding.progress_percent}%</p>
          <p class="text-xs text-muted-foreground">
            {#if remainingStepsCount === 0}
              All steps complete
            {:else}
              {remainingStepsCount} step{remainingStepsCount === 1 ? '' : 's'} left
            {/if}
          </p>
        </div>

        {#if onboarding.can_dismiss}
          <Button variant="ghost" size="sm" onclick={dismissOnboarding}>Dismiss</Button>
        {/if}
      </div>
    </Card.Header>

    <Card.Content class="grid gap-4 xl:grid-cols-[1fr_auto] xl:items-start">
      <div class="space-y-3">
        {#each stepsWithContent as step}
          <section class="rounded-lg border border-border bg-background p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <h3 class="font-medium text-foreground">{step.content.quickLabel}</h3>
                <p class="mt-1 text-sm text-muted-foreground">{step.content.quickDescription}</p>
              </div>
              <span class={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClasses(step.complete)}`}>
                {step.complete ? 'Done' : 'Next'}
              </span>
            </div>

            {#if step.href}
              <div class="mt-4">
                <Button href={step.href} size="sm" variant="outline">{step.content.ctaLabel}</Button>
              </div>
            {/if}
          </section>
        {/each}
      </div>

      <div class="flex xl:justify-end">
        <Button onclick={openDetails}>Open detailed onboarding</Button>
      </div>
    </Card.Content>
  </Card.Root>

  <DashboardOnboardingDetailsSheet bind:open={detailsOpen} {onboarding} />
{/if}